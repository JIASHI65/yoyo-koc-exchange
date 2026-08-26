// Supabase Edge Function: Discord API 代理
// 解决浏览器端 CORS 拦截问题
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const DISCORD_API = "https://discord.com/api/v10";

serve(async (req) => {
  // CORS 头（允许浏览器访问）
  const headers = new Headers({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
  });

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }

  try {
    const { action, data, token } = await req.json();
    if (!token) {
      return new Response(JSON.stringify({ ok: false, error: "缺少 Bot Token" }), {
        status: 400, headers,
      });
    }

    const authHeaders = {
      "Authorization": `Bot ${token}`,
      "Content-Type": "application/json",
    };

    let result;

    switch (action) {
      // 获取 Bot 实际加入的服务器
      case "list_guilds": {
        const res = await fetch(`${DISCORD_API}/users/@me/guilds`, { headers: authHeaders });
        const body = await res.text();
        if (!res.ok) {
          return new Response(JSON.stringify({ ok: false, error: `获取 Bot 服务器列表失败: ${res.status} ${body}` }), {
            status: res.status, headers,
          });
        }
        result = JSON.parse(body).map((guild: any) => ({ id: guild.id, name: guild.name }));
        break;
      }

      // 从 Bot 实际可访问的所有服务器拉取成员，避免前端写死错误 Guild ID
      case "list_all_members": {
        const guildRes = await fetch(`${DISCORD_API}/users/@me/guilds`, { headers: authHeaders });
        const guildBody = await guildRes.text();
        if (!guildRes.ok) {
          return new Response(JSON.stringify({ ok: false, error: `获取 Bot 服务器列表失败: ${guildRes.status} ${guildBody}` }), {
            status: guildRes.status, headers,
          });
        }
        const guilds = JSON.parse(guildBody);
        const memberMap = new Map<string, any>();
        const failures: string[] = [];
        for (const guild of guilds) {
          const memberRes = await fetch(`${DISCORD_API}/guilds/${guild.id}/members?limit=1000`, { headers: authHeaders });
          const memberBody = await memberRes.text();
          if (!memberRes.ok) {
            failures.push(`${guild.name} (${guild.id}): ${memberRes.status}`);
            continue;
          }
          for (const member of JSON.parse(memberBody)) {
            memberMap.set(member.user.id, {
              id: member.user.id,
              username: member.user.username,
              global_name: member.user.global_name || "",
              nick: member.nick || "",
              avatar: member.user.avatar,
              guild_id: guild.id,
              guild_name: guild.name,
            });
          }
        }
        if (memberMap.size === 0) {
          return new Response(JSON.stringify({
            ok: false,
            error: guilds.length === 0
              ? "MochiBot 尚未加入任何 Discord 服务器"
              : `MochiBot 无法读取服务器成员。请在 Discord Developer Portal 开启 Server Members Intent，并确认 Bot 仍在服务器中。${failures.length ? ` 失败: ${failures.join(", ")}` : ""}`,
          }), { status: 403, headers });
        }
        result = { members: Array.from(memberMap.values()), guilds: guilds.map((guild: any) => ({ id: guild.id, name: guild.name })), failures };
        break;
      }

      // 获取服务器所有成员
      case "list_members": {
        const { guild_id } = data;
        const res = await fetch(`${DISCORD_API}/guilds/${guild_id}/members?limit=1000`, {
          headers: authHeaders,
        });
        const body = await res.text();
        if (!res.ok) {
          return new Response(JSON.stringify({ ok: false, error: `获取成员失败: ${res.status} ${body}` }), {
            status: res.status, headers,
          });
        }
        const members = JSON.parse(body);
        result = members.map((m: any) => ({
          id: m.user.id,
          username: m.user.username,
          global_name: m.user.global_name || "",
          nick: m.nick || "",
          avatar: m.user.avatar,
        }));
        break;
      }

      // 获取指定频道的最近消息（用于新人入群自动欢迎）
      case "list_channel_messages": {
        const { channel_id, limit = 10 } = data;
        const safeLimit = Math.min(Math.max(Number(limit) || 10, 1), 100);
        const res = await fetch(`${DISCORD_API}/channels/${channel_id}/messages?limit=${safeLimit}`, {
          headers: authHeaders,
        });
        const body = await res.text();
        if (!res.ok) {
          return new Response(JSON.stringify({ ok: false, error: `获取频道消息失败: ${res.status} ${body}` }), {
            status: res.status, headers,
          });
        }
        result = JSON.parse(body);
        break;
      }

      // 发送私信给用户
      case "send_dm": {
        const { user_id, message } = data;
        // 1. 创建 DM 频道
        const dmRes = await fetch(`${DISCORD_API}/users/@me/channels`, {
          method: "POST",
          headers: authHeaders,
          body: JSON.stringify({ recipient_id: user_id }),
        });
        const dmBody = await dmRes.text();
        if (!dmRes.ok) {
          return new Response(JSON.stringify({ ok: false, error: `创建DM失败: ${dmRes.status} ${dmBody}` }), {
            status: dmRes.status, headers,
          });
        }
        const dm = JSON.parse(dmBody);
        // 2. 发送消息
        const msgRes = await fetch(`${DISCORD_API}/channels/${dm.id}/messages`, {
          method: "POST",
          headers: authHeaders,
          body: JSON.stringify({ content: message }),
        });
        const msgBody = await msgRes.text();
        if (!msgRes.ok) {
          return new Response(JSON.stringify({ ok: false, error: `发送消息失败: ${msgRes.status} ${msgBody}` }), {
            status: msgRes.status, headers,
          });
        }
        result = { ok: true, message_id: JSON.parse(msgBody).id };
        break;
      }

      default:
        return new Response(JSON.stringify({ ok: false, error: `未知操作: ${action}` }), {
          status: 400, headers,
        });
    }

    return new Response(JSON.stringify({ ok: true, data: result }), {
      status: 200, headers,
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ ok: false, error: e.message }), {
      status: 500, headers,
    });
  }
});
