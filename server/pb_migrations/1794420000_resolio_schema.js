/// <reference path="../pb_data/types.d.ts" />
// Schéma de la base Resolio.
// Chaque utilisateur ne voit et ne modifie QUE ses propres données (règles "user = @request.auth.id").
// "cid" = identifiant créé par l'application (hors ligne), unique par utilisateur.

const OWN = "user = @request.auth.id";
const CREATE_OWN = "@request.auth.id != '' && @request.body.user = @request.auth.id";
const UPDATE_OWN = "user = @request.auth.id && (@request.body.user:isset = false || @request.body.user = @request.auth.id)";

function timestamps() {
  return [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];
}

migrate((app) => {
  // --- utilisateurs : on ajoute la semaine de départ au profil ---
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new TextField({ name: "start_week", max: 10, pattern: "^(\\d{4}-\\d{2}-\\d{2})?$" }));
  app.save(users);

  const userRel = () => ({
    name: "user", type: "relation", required: true, maxSelect: 1,
    collectionId: users.id, cascadeDelete: true,
  });
  const rules = { listRule: OWN, viewRule: OWN, createRule: CREATE_OWN, updateRule: UPDATE_OWN, deleteRule: OWN };

  // --- objectifs ---
  app.save(new Collection(Object.assign({
    type: "base",
    name: "goals",
    fields: [
      userRel(),
      { name: "cid", type: "text", required: true, max: 64 },
      { name: "name", type: "text", required: true, max: 80 },
      { name: "emoji", type: "text", max: 16 },
      { name: "cat", type: "select", maxSelect: 1, values: ["reading", "sport", "other"] },
      { name: "type", type: "select", maxSelect: 1, values: ["count", "quantity", "daily", "once"] },
      { name: "unit", type: "text", max: 40 },
      { name: "activities", type: "json", maxSize: 20000 },
      { name: "distance", type: "bool" },
      { name: "created_week", type: "text", max: 10 },
      { name: "archived_week", type: "text", max: 10 },
      { name: "position", type: "number" },
      { name: "target_history", type: "json", maxSize: 100000 },
      { name: "injuries", type: "json", maxSize: 100000 },
      { name: "deleted", type: "bool" },
      ...timestamps(),
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_goals_user_cid ON goals (user, cid)",
      "CREATE INDEX idx_goals_user_updated ON goals (user, updated)",
    ],
  }, rules)));

  // --- semaines (clôture et bilan) ---
  app.save(new Collection(Object.assign({
    type: "base",
    name: "weeks",
    fields: [
      userRel(),
      { name: "week", type: "text", required: true, max: 10, pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
      { name: "closed", type: "bool" },
      { name: "result", type: "json", maxSize: 200000 },
      { name: "recap_seen", type: "bool" },
      ...timestamps(),
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_weeks_user_week ON weeks (user, week)",
      "CREATE INDEX idx_weeks_user_updated ON weeks (user, updated)",
    ],
  }, rules)));

  // --- enregistrements (une séance, une lecture, un jour coché…) ---
  app.save(new Collection(Object.assign({
    type: "base",
    name: "entries",
    fields: [
      userRel(),
      { name: "cid", type: "text", required: true, max: 64 },
      { name: "goal_cid", type: "text", required: true, max: 64 },
      { name: "week", type: "text", required: true, max: 10, pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
      { name: "date", type: "text", required: true, max: 10, pattern: "^\\d{4}-\\d{2}-\\d{2}$" },
      { name: "cat", type: "text", max: 20 },
      { name: "amount", type: "number" },
      { name: "book", type: "text", max: 200 },
      { name: "activity", type: "text", max: 80 },
      { name: "duration", type: "number" },
      { name: "distance", type: "number" },
      { name: "note", type: "text", max: 500 },
      { name: "at", type: "number" },
      { name: "deleted", type: "bool" },
      ...timestamps(),
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_entries_user_cid ON entries (user, cid)",
      "CREATE INDEX idx_entries_user_updated ON entries (user, updated)",
      "CREATE INDEX idx_entries_user_week ON entries (user, week)",
    ],
  }, rules)));
}, (app) => {
  for (const name of ["entries", "weeks", "goals"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch (e) {}
  }
  const users = app.findCollectionByNameOrId("users");
  users.fields.removeByName("start_week");
  app.save(users);
});
