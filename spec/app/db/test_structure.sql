CREATE TABLE `ac_assignments` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `parent_id` bigint(20) DEFAULT NULL,
  `role_id` int(11) NOT NULL,
  `principal_id` int(11) NOT NULL,
  `node_id` bigint(20) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_ac_assignments_on_parent_id` (`parent_id`),
  KEY `index_ac_assignments_on_role_id` (`role_id`),
  KEY `index_ac_assignments_on_principal_id` (`principal_id`),
  KEY `index_ac_assignments_on_node_id` (`node_id`),
  CONSTRAINT `constraint_ac_assignments_on_principal_id` FOREIGN KEY (`principal_id`) REFERENCES `ac_principals` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `constraint_ac_assignments_on_node_id` FOREIGN KEY (`node_id`) REFERENCES `ac_nodes` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `constraint_ac_assignments_on_parent_id` FOREIGN KEY (`parent_id`) REFERENCES `ac_assignments` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `constraint_ac_assignments_on_role_id` FOREIGN KEY (`role_id`) REFERENCES `ac_roles` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ac_nodes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `securable_type` varchar(40) NOT NULL,
  `securable_id` bigint(20) NOT NULL,
  `block` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_ac_nodes_on_securable_type_and_securable_id` (`securable_type`,`securable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ac_parents` (
  `parent_id` bigint(20) NOT NULL,
  `child_id` bigint(20) NOT NULL,
  UNIQUE KEY `index_ac_parents_on_parent_id_and_child_id` (`parent_id`,`child_id`),
  KEY `index_ac_parents_on_child_id` (`child_id`),
  CONSTRAINT `constraint_ac_parents_on_child_id` FOREIGN KEY (`child_id`) REFERENCES `ac_nodes` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `constraint_ac_parents_on_parent_id` FOREIGN KEY (`parent_id`) REFERENCES `ac_nodes` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ac_principals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `subject_type` varchar(40) NOT NULL,
  `subject_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_ac_principals_on_subject_type_and_subject_id` (`subject_type`,`subject_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ac_roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(40) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_ac_roles_on_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `ac_security_policy_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `permission` varchar(60) NOT NULL,
  `role_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_ac_security_policy_items_on_role_id_and_permission` (`role_id`,`permission`),
  CONSTRAINT `constraint_ac_security_policy_items_on_role_id` FOREIGN KEY (`role_id`) REFERENCES `ac_roles` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `field` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8_unicode_ci DEFAULT NULL,
  `record_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `records_records` (
  `from_id` int(11) DEFAULT NULL,
  `to_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) COLLATE utf8_unicode_ci NOT NULL,
  UNIQUE KEY `unique_schema_migrations` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

INSERT INTO schema_migrations (version) VALUES ('20110209170923');

INSERT INTO schema_migrations (version) VALUES ('20120112164736');