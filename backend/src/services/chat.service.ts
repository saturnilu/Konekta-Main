import { pool, DbRow, DbResult } from '../config/db';
import { ApiError } from '../utils/apiError';
import { notificationService } from './notification.service';

export const chatService = {
  async listConversations(userId: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT c.id, c.user_a_id, c.user_b_id, c.offer_id,
              c.last_message, c.last_message_at, c.created_at,
              CASE WHEN c.user_a_id = ? THEN c.user_b_id ELSE c.user_a_id END AS other_user_id,
              CASE WHEN c.user_a_id = ? THEN ub.name ELSE ua.name END AS other_user_name,
              CASE WHEN c.user_a_id = ? THEN ub.avatar_url ELSE ua.avatar_url END AS other_user_avatar_url,
              bp.brand_name, bp.logo_url AS brand_logo,
              ip.username AS influencer_username
         FROM conversations c
         JOIN users ua ON ua.id = c.user_a_id
         JOIN users ub ON ub.id = c.user_b_id
    LEFT JOIN brand_profiles bp ON (bp.user_id = c.user_a_id OR bp.user_id = c.user_b_id)
    LEFT JOIN influencer_profiles ip ON (ip.user_id = c.user_a_id OR ip.user_id = c.user_b_id)
        WHERE c.user_a_id = ? OR c.user_b_id = ?
        ORDER BY c.last_message_at DESC`,
      [userId, userId, userId, userId, userId]
    );
    return rows;
  },

  async ensureConversation(userAId: number, userBId: number) {
    const [exists] = await pool.query<DbRow[]>(
      `SELECT id FROM conversations
        WHERE (user_a_id = ? AND user_b_id = ?)
           OR (user_a_id = ? AND user_b_id = ?)
        LIMIT 1`,
      [userAId, userBId, userBId, userAId]
    );
    if (exists.length) return exists[0] as { id: number };
    const [lo, hi] = userAId < userBId ? [userAId, userBId] : [userBId, userAId];
    const [r] = await pool.query<DbResult>(
      `INSERT INTO conversations (user_a_id, user_b_id) VALUES (?, ?)`,
      [lo, hi]
    );
    return { id: r.insertId };
  },

  async ensureConversationByOtherUser(currentUserId: number, otherUserId: number) {
    return this.ensureConversation(currentUserId, otherUserId);
  },

  async listMessages(conversationId: number, userId: number) {
    await this.assertMember(conversationId, userId);
    const [rows] = await pool.query<DbRow[]>(
      `SELECT id, conversation_id, sender_user_id,
              message_text AS body, attachment_url, created_at,
              (sender_user_id = ?) AS is_mine
         FROM messages
        WHERE conversation_id = ?
        ORDER BY created_at ASC`,
      [userId, conversationId]
    );
    return rows;
  },

  async sendMessage(conversationId: number, senderId: number, body: string) {
    const conv = await this.assertMember(conversationId, senderId);
    const [r] = await pool.query<DbResult>(
      `INSERT INTO messages (conversation_id, sender_user_id, message_text) VALUES (?, ?, ?)`,
      [conversationId, senderId, body]
    );
    await pool.query(
      `UPDATE conversations SET last_message = ?, last_message_at = NOW() WHERE id = ?`,
      [body, conversationId]
    );

    try {
      const recipientId = conv.user_a_id === senderId ? conv.user_b_id : conv.user_a_id;
      const [senderRows] = await pool.query<DbRow[]>('SELECT name FROM users WHERE id = ?', [senderId]);
      const senderName = (senderRows[0] as { name?: string } | undefined)?.name ?? 'Someone';
      await notificationService.push(recipientId, {
        type: 'message',
        title: `New message from ${senderName}`,
        body: body.length > 140 ? `${body.slice(0, 140)}…` : body,
        data: { conversation_id: conversationId, other_user_id: senderId, other_user_name: senderName },
      });
    } catch {
    }

    const [rows] = await pool.query<DbRow[]>(
      `SELECT id, conversation_id, sender_user_id,
              message_text AS body, attachment_url, created_at,
              TRUE AS is_mine
         FROM messages WHERE id = ?`,
      [r.insertId]
    );
    return rows[0];
  },

  async assertMember(conversationId: number, userId: number) {
    const [rows] = await pool.query<DbRow[]>(
      `SELECT user_a_id, user_b_id FROM conversations WHERE id = ?`,
      [conversationId]
    );
    if (!rows.length) throw new ApiError(404, 'Conversation not found');
    const c = rows[0] as { user_a_id: number; user_b_id: number };
    if (c.user_a_id !== userId && c.user_b_id !== userId) {
      throw new ApiError(403, 'Not a member of this conversation');
    }
    return c;
  },
};