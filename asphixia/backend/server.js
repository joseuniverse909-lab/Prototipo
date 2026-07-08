const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.env.PORT || 3001);
const adminSecret = process.env.ADMIN_SECRET || 'dev-admin';
const adminEmails = new Set(
  String(process.env.ADMIN_EMAILS || 'joseuniverse909@gmail.com')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean)
);
const dbPath = path.join(__dirname, 'db.json');

const emptyDb = {
  users: [],
  clans: [],
  clanMessages: [],
  globalMessages: [],
  zones: [],
  events: [],
  photos: [],
  rewards: [
    {
      id: '1',
      name: 'Insignia verde',
      description: 'Marca tu perfil como jugador ecologico.',
      cost: 250
    },
    {
      id: '2',
      name: 'Boost x2 por 1h',
      description: 'Duplica tus puntos durante la proxima actividad.',
      cost: 500
    }
  ],
  redemptions: [],
  notifications: [],
  pointLedger: []
};

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function normalizeDb(raw) {
  const db = { ...clone(emptyDb), ...raw };
  for (const key of Object.keys(emptyDb)) {
    if (!Array.isArray(db[key])) db[key] = clone(emptyDb[key]);
  }
  return db;
}

function readDb() {
  if (!fs.existsSync(dbPath)) {
    writeDb(emptyDb);
    return clone(emptyDb);
  }
  return normalizeDb(JSON.parse(fs.readFileSync(dbPath, 'utf8')));
}

function writeDb(db) {
  fs.writeFileSync(dbPath, JSON.stringify(normalizeDb(db), null, 2));
}

function send(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers':
      'Content-Type,Authorization,X-Admin-Secret,X-User-Email'
  });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch (error) {
        reject(error);
      }
    });
  });
}

function routeParts(url) {
  const parts = url.pathname.split('/').filter(Boolean);
  return parts[0] === 'api' ? parts.slice(1) : parts;
}

function isAdmin(req) {
  if (req.headers['x-admin-secret'] === adminSecret) return true;
  const email = String(req.headers['x-user-email'] || '').toLowerCase();
  return adminEmails.has(email);
}

function requireAdmin(req, res) {
  if (isAdmin(req)) return true;
  send(res, 403, { error: 'Admin requerido' });
  return false;
}

function upsert(list, item) {
  const now = new Date().toISOString();
  const saved = {
    id: String(item.id || Date.now()),
    createdAt: item.createdAt || now,
    ...item,
    updatedAt: now
  };
  const index = list.findIndex((entry) => entry.id === saved.id);
  if (index === -1) list.push(saved);
  else list[index] = { ...list[index], ...saved };
  return saved;
}

function findUser(db, userId) {
  return db.users.find((user) => user.id === userId);
}

function userClan(db, userId) {
  if (!userId) return null;
  return db.clans.find(
    (clan) =>
      clan.ownerId === userId ||
      (Array.isArray(clan.memberIds) && clan.memberIds.includes(userId))
  );
}

function upsertUser(db, user) {
  const existing = user.id ? findUser(db, user.id) : null;
  const role = adminEmails.has(String(user.email || '').toLowerCase())
    ? 'admin'
    : existing?.role || user.role || 'player';
  return upsert(db.users, {
    points: existing ? Number(existing.points || 0) : 0,
    clanId: existing?.clanId || '',
    ...user,
    role,
    points:
      typeof user.points === 'number'
        ? user.points
        : existing
          ? Number(existing.points || 0)
          : 0
  });
}

function addUserPoints(db, userId, points, reason = 'Puntos') {
  if (!userId) return null;
  const amount = Number(points || 0);
  const user = findUser(db, userId) || upsertUser(db, { id: userId });
  user.points = Math.max(0, Number(user.points || 0) + amount);
  user.updatedAt = new Date().toISOString();
  db.pointLedger.unshift({
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    userId,
    points: amount,
    reason,
    createdAt: new Date().toISOString()
  });
  return user;
}

function priorityScore(speedMetersPerSecond, laps) {
  return Number(speedMetersPerSecond || 0) + Number(laps || 0) * 0.35;
}

function zoneWithScore(zone) {
  return {
    ...zone,
    priorityScore: priorityScore(zone.bestSpeedMetersPerSecond, zone.laps)
  };
}

function validateClanWrite(db, body) {
  const memberIds = Array.isArray(body.memberIds) ? body.memberIds : [];
  const ownerId = body.ownerId || memberIds[0] || '';
  const existing = body.id ? db.clans.find((clan) => clan.id === body.id) : null;

  if (!existing && userClan(db, ownerId)) {
    return 'Solo puedes crear un clan por persona.';
  }

  for (const memberId of memberIds) {
    const clan = userClan(db, memberId);
    if (clan && clan.id !== body.id) {
      return 'Un usuario que ya esta en un clan no puede unirse a otro.';
    }
  }

  return null;
}

function notifyUser(db, userId, title, message) {
  if (!userId) return;
  db.notifications.unshift({
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    userId,
    title,
    message,
    createdAt: new Date().toISOString()
  });
}

async function handleUsers(req, res, parts, db) {
  if (parts[0] !== 'users') return false;

  if (parts.length === 1 && req.method === 'GET') {
    send(res, 200, db.users);
    return true;
  }

  if (parts.length === 1 && (req.method === 'POST' || req.method === 'PUT')) {
    const body = await readBody(req);
    const saved = upsertUser(db, body);
    writeDb(db);
    send(res, req.method === 'POST' ? 201 : 200, saved);
    return true;
  }

  if (parts.length === 2 && req.method === 'GET') {
    const user = findUser(db, parts[1]);
    send(res, user ? 200 : 404, user || { error: 'Usuario no encontrado' });
    return true;
  }

  if (parts.length === 3 && parts[2] === 'points' && req.method === 'POST') {
    const body = await readBody(req);
    const user = addUserPoints(db, parts[1], body.points, body.reason);
    writeDb(db);
    send(res, 200, user);
    return true;
  }

  if (
    parts.length === 3 &&
    parts[2] === 'notifications' &&
    req.method === 'GET'
  ) {
    send(
      res,
      200,
      db.notifications.filter((item) => item.userId === parts[1])
    );
    return true;
  }

  return false;
}

async function handleClanMessages(req, res, parts, db) {
  if (parts[0] !== 'clans' || parts.length !== 3 || parts[2] !== 'messages') {
    return false;
  }

  const clanId = parts[1];
  const clan = db.clans.find((item) => item.id === clanId);

  if (req.method === 'GET') {
    const messages = db.clanMessages
      .filter((message) => message.clanId === clanId)
      .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)))
      .slice(-120);
    send(res, 200, messages);
    return true;
  }

  if (req.method === 'POST') {
    const body = await readBody(req);
    if (
      clan &&
      Array.isArray(clan.memberIds) &&
      !clan.memberIds.includes(body.userId)
    ) {
      send(res, 403, { error: 'Solo miembros pueden chatear' });
      return true;
    }
    const saved = upsert(db.clanMessages, {
      ...body,
      clanId,
      text: String(body.text || '').slice(0, 500)
    });
    writeDb(db);
    send(res, 201, saved);
    return true;
  }

  return false;
}

async function handleGlobalMessages(req, res, parts, db) {
  if (parts[0] !== 'global' || parts[1] !== 'messages') return false;

  if (req.method === 'GET') {
    const messages = db.globalMessages
      .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)))
      .slice(-120);
    send(res, 200, messages);
    return true;
  }

  if (req.method === 'POST') {
    const body = await readBody(req);
    const saved = upsert(db.globalMessages, {
      ...body,
      clanId: 'global',
      text: String(body.text || '').slice(0, 500)
    });
    writeDb(db);
    send(res, 201, saved);
    return true;
  }

  return false;
}

async function handleAdminRoutes(req, res, parts, db) {
  if (parts[0] !== 'admin') return false;
  if (!requireAdmin(req, res)) return true;

  if (parts[1] === 'photos' && parts[2] === 'validate' && req.method === 'POST') {
    const body = await readBody(req);
    const photo = db.photos.find((item) => item.id === body.photoId);
    if (!photo) {
      send(res, 404, { error: 'Foto no encontrada' });
      return true;
    }

    photo.status = body.status === 'approved' ? 'approved' : 'rejected';
    photo.awardedPoints = Number(body.awardedPoints || 0);
    photo.updatedAt = new Date().toISOString();

    if (photo.status === 'approved' && photo.awardedPoints > 0) {
      addUserPoints(db, photo.userId, photo.awardedPoints, 'Foto validada');
    }

    writeDb(db);
    send(res, 200, photo);
    return true;
  }

  if (parts[1] === 'events' && parts[2] === 'finish' && req.method === 'POST') {
    const body = await readBody(req);
    const event = db.events.find((item) => item.id === body.eventId);
    if (!event) {
      send(res, 404, { error: 'Evento no encontrado' });
      return true;
    }

    event.isActive = false;
    event.winningClanId = body.winningClanId || null;
    event.updatedAt = new Date().toISOString();

    const clan = db.clans.find((item) => item.id === event.winningClanId);
    if (clan) {
      clan.eventPoints =
        Number(clan.eventPoints || 0) + Number(event.bonusPoints || 0);
      clan.updatedAt = new Date().toISOString();
    }

    writeDb(db);
    send(res, 200, event);
    return true;
  }

  send(res, 404, { error: 'Ruta admin no encontrada' });
  return true;
}

async function handleZoneChallenge(req, res, parts, db) {
  if (parts[0] !== 'zones' || parts[1] !== 'challenge' || req.method !== 'POST') {
    return false;
  }

  const body = await readBody(req);
  const zone = db.zones.find((item) => item.id === body.zoneId);
  if (!zone) {
    send(res, 404, { error: 'Zona no encontrada' });
    return true;
  }
  if (zone.state === 'forbidden') {
    send(res, 409, { error: 'Zona prohibida' });
    return true;
  }

  const challengerScore = priorityScore(body.speedMetersPerSecond, body.laps);
  const currentScore = priorityScore(zone.bestSpeedMetersPerSecond, zone.laps);
  const won = challengerScore > currentScore || zone.state !== 'claimed';

  if (won) {
    zone.ownerId = body.userId || zone.ownerId || '';
    zone.ownerName = body.userName || zone.ownerName || 'Jugador';
    zone.clanId = body.clanId || zone.clanId || '';
    zone.state = 'claimed';
    zone.laps = Number(body.laps || 0);
    zone.bestSpeedMetersPerSecond = Number(body.speedMetersPerSecond || 0);
    zone.updatedAt = new Date().toISOString();
    addUserPoints(db, zone.ownerId, 10, 'Zona claimeada');
    const clan = db.clans.find((item) => item.id === zone.clanId);
    if (clan) clan.eventPoints = Number(clan.eventPoints || 0) + 10;
    writeDb(db);
  }

  send(res, 200, {
    won,
    currentScore,
    challengerScore,
    zone: zoneWithScore(zone)
  });
  return true;
}

async function handleCollection(req, res, parts, db) {
  if (parts.length !== 1) return false;
  const name = parts[0];
  if (!Array.isArray(db[name])) return false;

  const adminCollections = new Set(['events', 'rewards']);

  if (req.method === 'GET') {
    const data = name === 'zones' ? db[name].map(zoneWithScore) : db[name];
    send(res, 200, data);
    return true;
  }

  if (req.method === 'POST' || req.method === 'PUT') {
    if (adminCollections.has(name) && !requireAdmin(req, res)) return true;
    if (name === 'redemptions' && req.method === 'PUT' && !requireAdmin(req, res)) {
      return true;
    }

    const body = await readBody(req);

    if (name === 'clans') {
      const error = validateClanWrite(db, body);
      if (error) {
        send(res, 409, { error });
        return true;
      }
      body.memberIds = Array.from(
        new Set(
          [
            body.ownerId,
            ...(Array.isArray(body.memberIds) ? body.memberIds : [])
          ].filter(Boolean)
        )
      );
    }

    const saved = upsert(db[name], body);

    if (name === 'clans' && Array.isArray(saved.memberIds)) {
      for (const userId of saved.memberIds) {
        const user = findUser(db, userId) || upsertUser(db, { id: userId });
        user.clanId = saved.id;
      }
    }

    if (name === 'redemptions' && req.method === 'PUT') {
      notifyUser(
        db,
        saved.userId,
        `Canje ${saved.status === 'delivered' ? 'aprobado' : 'actualizado'}`,
        saved.adminMessage ||
          `Tu canje de ${saved.rewardName} fue actualizado.`
      );
      if (saved.status === 'rejected') {
        addUserPoints(db, saved.userId, Number(saved.cost || 0), 'Canje rechazado');
      }
    }

    writeDb(db);
    send(res, req.method === 'POST' ? 201 : 200, saved);
    return true;
  }

  if (req.method === 'DELETE') {
    if (adminCollections.has(name) && !requireAdmin(req, res)) return true;
    const url = new URL(req.url, `http://${req.headers.host}`);
    const id = url.searchParams.get('id');
    db[name] = id ? db[name].filter((entry) => entry.id !== id) : [];
    writeDb(db);
    send(res, 200, { ok: true });
    return true;
  }

  send(res, 405, { error: 'Metodo no permitido' });
  return true;
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return send(res, 200, {});

  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const parts = routeParts(url);
    const db = readDb();

    if (url.pathname === '/health' || url.pathname === '/api/health') {
      send(res, 200, {
        ok: true,
        app: 'Asphixia',
        runtime: 'local-json',
        collections: Object.keys(emptyDb)
      });
      return;
    }

    if (await handleUsers(req, res, parts, db)) return;
    if (await handleClanMessages(req, res, parts, db)) return;
    if (await handleGlobalMessages(req, res, parts, db)) return;
    if (await handleAdminRoutes(req, res, parts, db)) return;
    if (await handleZoneChallenge(req, res, parts, db)) return;
    if (await handleCollection(req, res, parts, db)) return;

    send(res, 404, { error: 'Ruta no encontrada' });
  } catch (error) {
    send(res, 500, { error: error.message });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Asphixia backend local en http://0.0.0.0:${port}`);
});
