// ── EDGE FUNCTION: recordatorios-tareas ───────────────────────────────────────
// Envía correos de recordatorio a los usuarios cuando una tarea se acerca a su
// fecha de vencimiento. Se ejecuta una vez al día a las 08:00 UTC vía pg_cron.
//
// INTERVALOS DE ALERTA:
//   • 7 días antes  → "Tu tarea vence en una semana"
//   • 5 días antes  → "Tu tarea vence en 5 días"
//   • 3 días antes  → "Tu tarea vence en 3 días"
//   • 0 días        → "Tu tarea vence HOY"
//
// ANTI-DUPLICADOS:
//   Usa la tabla `task_reminders_sent` para registrar qué intervalos ya se
//   enviaron por tarea. La constraint UNIQUE(task_id, dias_restantes) garantiza
//   que el mismo recordatorio nunca se envíe dos veces, aunque el cron falle y
//   se reintente el mismo día.
//
// VARIABLES DE ENTORNO REQUERIDAS (Supabase Dashboard → Edge Functions → Secrets):
//   RESEND_API_KEY  → Tu clave de API de Resend (https://resend.com)
//   FROM_EMAIL      → Dirección remitente, ej: "ProTask <noreply@tudominio.com>"
//   SUPABASE_URL    → Se inyecta automáticamente por Supabase
//   SUPABASE_SERVICE_ROLE_KEY → Se inyecta automáticamente por Supabase

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── TIPOS ──────────────────────────────────────────────────────────────────────

interface TareaConUsuario {
  id: string;
  title: string;
  due_date: string;
  status: string;
  // Datos del usuario asignado (puede ser null si la tarea no está asignada)
  assigned_to: string | null;
  assigned_profile: { email: string | null; full_name: string | null } | null;
  // Datos del creador (fallback si no hay assigned_to)
  created_by: string | null;
  creator_profile: { email: string | null; full_name: string | null } | null;
  // Nombre del proyecto al que pertenece
  project_name: string | null;
}

interface ResultadoEnvio {
  tarea_id: string;
  titulo: string;
  dias_restantes: number;
  email_destino: string;
  enviado: boolean;
  error?: string;
}

// ── HANDLER PRINCIPAL ──────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // Solo aceptamos POST (así lo llama pg_net desde pg_cron)
  // También permitimos GET para poder probarla manualmente desde el Dashboard
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  // ── CLIENTE SUPABASE CON SERVICE ROLE ───────────────────────────────────────
  // Usamos la service_role key para poder leer perfiles y tareas de todos los
  // usuarios. Esta función nunca se expone al cliente; solo la llama pg_cron.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const fromEmail = Deno.env.get("FROM_EMAIL") ?? "ProTask <noreply@protask.app>";

  if (!resendApiKey) {
    console.error("❌ RESEND_API_KEY no está configurada en los secrets");
    return new Response(
      JSON.stringify({ error: "RESEND_API_KEY no configurada" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // ── INTERVALOS A COMPROBAR HOY ──────────────────────────────────────────────
  // Para cada intervalo calculamos la fecha exacta que debe tener una tarea
  // para recibir hoy su recordatorio correspondiente.
  const intervalos = [7, 5, 3, 0]; // días de antelación
  const resultados: ResultadoEnvio[] = [];
  let totalEnviados = 0;
  let totalErrores = 0;

  for (const diasRestantes of intervalos) {
    console.log(`\n📅 Procesando recordatorios de ${diasRestantes} días...`);

    // ── CONSULTA: tareas que vencen en exactamente N días ─────────────────────
    // Usamos date_trunc('day', ...) para comparar solo la parte de fecha (sin hora).
    // Esto garantiza que una tarea con due_date = '2025-12-25 23:59' siga entrando
    // en el recordatorio del día 25, independientemente de la hora configurada.
    const fechaObjetivo = new Date();
    fechaObjetivo.setUTCDate(fechaObjetivo.getUTCDate() + diasRestantes);
    const fechaObjetivoStr = fechaObjetivo.toISOString().split("T")[0]; // 'YYYY-MM-DD'

    // Obtenemos las tareas con sus datos de perfil en una sola consulta usando joins
    const { data: tareas, error: errorConsulta } = await supabase
      .from("tasks")
      .select(`
        id,
        title,
        due_date,
        status,
        assigned_to,
        assigned_profile:profiles!tasks_assigned_to_fkey(email, full_name),
        created_by,
        creator_profile:profiles!tasks_created_by_fkey(email, full_name),
        project:projects!tasks_project_id_fkey(name)
      `)
      .not("due_date", "is", null)         // Solo tareas con fecha límite
      .neq("status", "done")               // Ignoramos tareas ya finalizadas
      .gte("due_date", `${fechaObjetivoStr}T00:00:00.000Z`)
      .lte("due_date", `${fechaObjetivoStr}T23:59:59.999Z`);

    if (errorConsulta) {
      console.error(`❌ Error consultando tareas para ${diasRestantes} días:`, errorConsulta);
      continue;
    }

    if (!tareas || tareas.length === 0) {
      console.log(`   Sin tareas para este intervalo.`);
      continue;
    }

    console.log(`   Encontradas ${tareas.length} tarea(s) candidatas.`);

    // ── FILTRO ANTI-DUPLICADOS ─────────────────────────────────────────────────
    // Comprobamos cuáles ya tienen registrado el recordatorio de este intervalo
    const tareaIds = tareas.map((t: any) => t.id);

    const { data: yaEnviados } = await supabase
      .from("task_reminders_sent")
      .select("task_id")
      .in("task_id", tareaIds)
      .eq("dias_restantes", diasRestantes);

    const idsYaEnviados = new Set((yaEnviados ?? []).map((r: any) => r.task_id));

    // Filtramos las tareas que aún NO tienen el recordatorio de este intervalo
    const tareasParaEnviar = tareas.filter((t: any) => !idsYaEnviados.has(t.id));

    console.log(
      `   ${idsYaEnviados.size} ya enviados, ${tareasParaEnviar.length} pendientes.`,
    );

    // ── ENVÍO DE CORREOS ───────────────────────────────────────────────────────
    for (const tarea of tareasParaEnviar) {
      // Determinamos el destinatario: preferimos assigned_to; si no, creator
      // Normalizamos el resultado del join (Supabase puede devolver objeto o array)
      const assignedProfile = Array.isArray(tarea.assigned_profile)
        ? tarea.assigned_profile[0]
        : tarea.assigned_profile;
      const creatorProfile = Array.isArray(tarea.creator_profile)
        ? tarea.creator_profile[0]
        : tarea.creator_profile;
      const projectName = Array.isArray(tarea.project)
        ? tarea.project[0]?.name
        : tarea.project?.name;

      // Si hay usuario asignado con email, le enviamos a él; sino al creador
      const perfil = assignedProfile?.email ? assignedProfile : creatorProfile;

      if (!perfil?.email) {
        console.warn(`   ⚠️  Tarea "${tarea.title}" sin email destinatario. Saltando.`);
        continue;
      }

      const emailDestino = perfil.email;
      const nombreDestino = perfil.full_name ?? emailDestino;

      // ── CONSTRUIR Y ENVIAR EL EMAIL ──────────────────────────────────────────
      const { asunto, cuerpoHtml } = construirEmail({
        nombreDestino,
        titulotarea: tarea.title,
        nombreProyecto: projectName ?? "Sin proyecto",
        diasRestantes,
        fechaVencimiento: tarea.due_date,
      });

      const enviado = await enviarEmailResend({
        apiKey: resendApiKey,
        from: fromEmail,
        to: emailDestino,
        subject: asunto,
        html: cuerpoHtml,
      });

      const resultado: ResultadoEnvio = {
        tarea_id: tarea.id,
        titulo: tarea.title,
        dias_restantes: diasRestantes,
        email_destino: emailDestino,
        enviado,
      };

      if (enviado) {
        // ── REGISTRAR EN task_reminders_sent ──────────────────────────────────
        // La constraint UNIQUE(task_id, dias_restantes) actúa como segunda
        // línea de defensa: si por algún bug se llega aquí dos veces,
        // el INSERT falla silenciosamente y no hay duplicado en la BD.
        await supabase
          .from("task_reminders_sent")
          .insert({ task_id: tarea.id, dias_restantes: diasRestantes })
          .throwOnError()
          .catch((e: Error) =>
            console.warn(`   ⚠️  No se pudo registrar reminder (posible duplicado): ${e.message}`)
          );

        console.log(`   ✅ Email enviado a ${emailDestino} para "${tarea.title}"`);
        totalEnviados++;
      } else {
        resultado.error = "Error al llamar a la API de Resend";
        console.error(`   ❌ Fallo al enviar a ${emailDestino} para "${tarea.title}"`);
        totalErrores++;
      }

      resultados.push(resultado);
    }
  }

  // ── RESPUESTA FINAL ────────────────────────────────────────────────────────
  const resumen = {
    ejecutado_en: new Date().toISOString(),
    total_enviados: totalEnviados,
    total_errores: totalErrores,
    detalle: resultados,
  };

  console.log("\n📊 Resumen:", JSON.stringify(resumen, null, 2));

  return new Response(JSON.stringify(resumen), {
    headers: { "Content-Type": "application/json" },
  });
});

// ── HELPER: CONSTRUIR EMAIL ────────────────────────────────────────────────────
// Genera el asunto y el cuerpo HTML según los días restantes.
// El HTML usa estilos inline para máxima compatibilidad con clientes de correo.
function construirEmail(opts: {
  nombreDestino: string;
  titulotarea: string;
  nombreProyecto: string;
  diasRestantes: number;
  fechaVencimiento: string;
}): { asunto: string; cuerpoHtml: string } {
  const { nombreDestino, titulotarea, nombreProyecto, diasRestantes, fechaVencimiento } = opts;

  // Formateamos la fecha de vencimiento en español
  const fecha = new Date(fechaVencimiento);
  const fechaFormateada = fecha.toLocaleDateString("es-ES", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });

  // Asunto y color de urgencia según el intervalo
  let asunto: string;
  let colorUrgencia: string;
  let mensajeUrgencia: string;

  if (diasRestantes === 0) {
    asunto = `🚨 ProTask — La tarea "${titulotarea}" vence HOY`;
    colorUrgencia = "#FF4444";
    mensajeUrgencia = "¡La tarea vence <strong>HOY</strong>! Es el último día para completarla.";
  } else if (diasRestantes === 3) {
    asunto = `⚠️ ProTask — La tarea "${titulotarea}" vence en 3 días`;
    colorUrgencia = "#FF8C00";
    mensajeUrgencia = `Quedan solo <strong>${diasRestantes} días</strong> para la fecha límite.`;
  } else if (diasRestantes === 5) {
    asunto = `📅 ProTask — La tarea "${titulotarea}" vence en 5 días`;
    colorUrgencia = "#E8622A";
    mensajeUrgencia = `Quedan <strong>${diasRestantes} días</strong> para la fecha límite.`;
  } else {
    asunto = `📋 ProTask — La tarea "${titulotarea}" vence en ${diasRestantes} días`;
    colorUrgencia = "#4A90E2";
    mensajeUrgencia = `Quedan <strong>${diasRestantes} días</strong> para la fecha límite.`;
  }

  // ── PLANTILLA HTML ─────────────────────────────────────────────────────────
  const cuerpoHtml = `
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#1E2030;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#1E2030;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#2D3142;border-radius:16px;overflow:hidden;border:1px solid #3A3D52;">

          <!-- CABECERA -->
          <tr>
            <td style="background:linear-gradient(135deg,#232537,#2D3142);padding:32px;text-align:center;border-bottom:2px solid ${colorUrgencia};">
              <p style="margin:0;font-size:28px;font-weight:800;color:#E8622A;letter-spacing:2px;">Pro Task</p>
              <p style="margin:8px 0 0;font-size:13px;color:#AAADBF;">Gestión de proyectos y tareas</p>
            </td>
          </tr>

          <!-- BADGE DE URGENCIA -->
          <tr>
            <td style="padding:24px 32px 0;text-align:center;">
              <span style="display:inline-block;background-color:${colorUrgencia};color:white;padding:6px 20px;border-radius:100px;font-size:13px;font-weight:700;letter-spacing:1px;">
                ${diasRestantes === 0 ? "VENCE HOY" : `${diasRestantes} DÍAS RESTANTES`}
              </span>
            </td>
          </tr>

          <!-- CUERPO -->
          <tr>
            <td style="padding:24px 32px 32px;">
              <p style="margin:0 0 16px;font-size:16px;color:#CCCEDF;">Hola, <strong style="color:white;">${nombreDestino}</strong></p>
              <p style="margin:0 0 24px;font-size:15px;color:#AAADBF;line-height:1.6;">${mensajeUrgencia}</p>

              <!-- TARJETA DE TAREA -->
              <div style="background-color:#3A3D52;border-radius:12px;padding:20px;border-left:4px solid ${colorUrgencia};margin-bottom:24px;">
                <p style="margin:0 0 8px;font-size:11px;font-weight:700;color:#AAADBF;letter-spacing:1px;text-transform:uppercase;">Tarea</p>
                <p style="margin:0 0 16px;font-size:18px;font-weight:700;color:white;">${titulotarea}</p>

                <p style="margin:0 0 4px;font-size:11px;font-weight:700;color:#AAADBF;letter-spacing:1px;text-transform:uppercase;">Proyecto</p>
                <p style="margin:0 0 16px;font-size:14px;color:#CCCEDF;">${nombreProyecto}</p>

                <p style="margin:0 0 4px;font-size:11px;font-weight:700;color:#AAADBF;letter-spacing:1px;text-transform:uppercase;">Fecha límite</p>
                <p style="margin:0;font-size:14px;color:${colorUrgencia};font-weight:600;">${fechaFormateada}</p>
              </div>

              <p style="margin:0;font-size:14px;color:#AAADBF;line-height:1.6;">
                Accede a <strong style="color:#E8622A;">ProTask</strong> para actualizar el estado de la tarea o marcarla como completada.
              </p>
            </td>
          </tr>

          <!-- PIE -->
          <tr>
            <td style="padding:20px 32px;border-top:1px solid #3A3D52;text-align:center;">
              <p style="margin:0;font-size:12px;color:#6B6E85;">
                Este correo fue enviado automáticamente por ProTask.<br>
                Si no esperabas este mensaje, puedes ignorarlo.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  return { asunto, cuerpoHtml };
}

// ── HELPER: ENVIAR EMAIL VÍA RESEND ───────────────────────────────────────────
// Resend es el proveedor de email recomendado para proyectos Supabase/Deno.
// Documentación: https://resend.com/docs
async function enviarEmailResend(opts: {
  apiKey: string;
  from: string;
  to: string;
  subject: string;
  html: string;
}): Promise<boolean> {
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${opts.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: opts.from,
        to: [opts.to],
        subject: opts.subject,
        html: opts.html,
      }),
    });

    if (!res.ok) {
      const errorBody = await res.text();
      console.error(`   Resend API error ${res.status}: ${errorBody}`);
      return false;
    }

    return true;
  } catch (e) {
    console.error("   Error de red al llamar a Resend:", e);
    return false;
  }
}