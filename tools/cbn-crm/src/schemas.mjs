import { z } from 'zod';
export const id = z.number().int().positive().max(Number.MAX_SAFE_INTEGER);
export const empty = z.strictObject({});
const text = z.string().trim().min(1).max(10000);
const scheduledLocal = z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/, 'Use data e hora de Brasília: YYYY-MM-DDTHH:mm');
const condition = z.strictObject({ attribute_key: z.string().min(1).max(100), filter_operator: z.string().min(1).max(60), query_operator: z.enum(['AND', 'OR']).nullable().optional(), custom_attribute_type: z.string().max(60).optional(), values: z.array(z.union([z.string().max(10000), z.number(), z.boolean()])).max(50) });
const ruleAction = z.strictObject({ action_name: z.string().min(1).max(100), action_params: z.array(z.union([z.string().max(10000), z.number()])).max(50) });
const rule = z.strictObject({ name: z.string().trim().min(1).max(150), description: z.string().max(1000).optional(), event_name: z.enum(['conversation_created', 'conversation_updated', 'message_created']), active: z.boolean().default(false), conditions: z.array(condition).min(1).max(30), actions: z.array(ruleAction).min(1).max(20) });
export const actionSchema = z.discriminatedUnion('kind', [
  z.strictObject({ kind: z.literal('send_message'), conversation_id: id, content: text, private: z.boolean().default(false), reply_to: id.optional() }),
  z.strictObject({ kind: z.literal('send_media'), conversation_id: id, upload_id: z.uuid(), content: z.string().max(10000).default(''), private: z.boolean().default(false) }),
  z.strictObject({ kind: z.literal('schedule_create'), conversation_id: id, content: z.string().trim().max(10000).default(''), scheduled_local: scheduledLocal, upload_ids: z.array(z.uuid()).max(10).default([]) }),
  z.strictObject({ kind: z.literal('schedule_update'), conversation_id: id, schedule_id: id, content: z.string().trim().max(10000).default(''), scheduled_local: scheduledLocal, upload_ids: z.array(z.uuid()).max(10).default([]), remove_attachment_ids: z.array(id).max(10).default([]) }),
  z.strictObject({ kind: z.literal('schedule_cancel'), conversation_id: id, schedule_id: id }),
  z.strictObject({ kind: z.literal('conversation_status'), conversation_id: id, status: z.enum(['open', 'resolved', 'pending']) }),
  z.strictObject({ kind: z.literal('automation_create'), rule }),
  z.strictObject({ kind: z.literal('automation_set_active'), rule_id: id, active: z.boolean() }),
]).superRefine((action, ctx) => {
  if (action.kind === 'schedule_create' && !action.content && !action.upload_ids.length) {
    ctx.addIssue({ code: 'custom', message: 'Escreva uma mensagem ou adicione um anexo.', path: ['content'] });
  }
  if (action.upload_ids && new Set(action.upload_ids).size !== action.upload_ids.length) {
    ctx.addIssue({ code: 'custom', message: 'Não repita o mesmo upload no agendamento.', path: ['upload_ids'] });
  }
});
export const prepareSchema = z.strictObject({ operation_id: z.uuid().describe('UUID estável para esta intenção. Reutilize ao repetir a mesma preparação.'), action: actionSchema });
export const executeSchema = z.strictObject({ action_id: z.uuid(), approval_reference: z.string().trim().min(3).max(1000).describe('Instrução real do usuário que autoriza esta ação/destinatário. Não invente aprovação; pode citar autorização de atendimento já vigente.') });
export const attachmentSchema = z.strictObject({ conversation_id: id, message_id: id, attachment_id: id, format: z.enum(['metadata', 'inline', 'download', 'transcribe']).default('metadata') });
