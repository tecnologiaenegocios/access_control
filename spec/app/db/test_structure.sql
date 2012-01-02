CREATE TABLE "ac_assignments" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "node_id" integer(8) NOT NULL, "principal_id" integer NOT NULL, "role_id" integer NOT NULL, "lock_version" integer DEFAULT 0);
CREATE TABLE "ac_nodes" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "securable_type" varchar(40) NOT NULL, "securable_id" integer(8) NOT NULL, "block" boolean DEFAULT 'f' NOT NULL, "lock_version" integer DEFAULT 0);
CREATE TABLE "ac_parents" ("parent_id" integer(8) NOT NULL, "child_id" integer(8) NOT NULL);
CREATE TABLE "ac_principals" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "subject_type" varchar(40) NOT NULL, "subject_id" integer NOT NULL, "lock_version" integer DEFAULT 0);
CREATE TABLE "ac_roles" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(40) NOT NULL, "title" varchar(40), "description" varchar(150), "local" boolean DEFAULT 't' NOT NULL, "global" boolean DEFAULT 't' NOT NULL, "lock_version" integer DEFAULT 0);
CREATE TABLE "ac_security_policy_items" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "permission" varchar(60) NOT NULL, "role_id" integer NOT NULL, "lock_version" integer DEFAULT 0);
CREATE TABLE "records" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "field" integer, "name" varchar(255), "record_id" integer);
CREATE TABLE "records_records" ("from_id" integer, "to_id" integer);
CREATE TABLE "schema_migrations" ("version" varchar(255) NOT NULL);
CREATE UNIQUE INDEX "index_ac_nodes_on_securable_type_and_securable_id" ON "ac_nodes" ("securable_type", "securable_id");
CREATE UNIQUE INDEX "index_ac_parents_on_parent_id_and_child_id" ON "ac_parents" ("parent_id", "child_id");
CREATE UNIQUE INDEX "index_ac_principals_on_subject_type_and_subject_id" ON "ac_principals" ("subject_type", "subject_id");
CREATE UNIQUE INDEX "index_ac_roles_on_name" ON "ac_roles" ("name");
CREATE UNIQUE INDEX "index_ac_security_policy_items_on_permission_and_role_id" ON "ac_security_policy_items" ("permission", "role_id");
CREATE UNIQUE INDEX "index_on_principal_id_and_node_id_and_role_id" ON "ac_assignments" ("principal_id", "node_id", "role_id");
CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version");
INSERT INTO schema_migrations (version) VALUES ('20120102171934');

INSERT INTO schema_migrations (version) VALUES ('20110209170923');