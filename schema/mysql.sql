-- TODO: everywhere: ctime, mtime!

SET sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,PIPES_AS_CONCAT,ANSI_QUOTES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER';

CREATE TABLE director_dbversion (
  schema_version INT(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_activity_log (
  id BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_type VARCHAR(64) NOT NULL,
  object_name VARCHAR(255) NOT NULL,
  action_name ENUM('create', 'delete', 'modify') NOT NULL,
  old_properties TEXT DEFAULT NULL COMMENT 'Property hash, JSON',
  new_properties TEXT DEFAULT NULL COMMENT 'Property hash, JSON',
  author VARCHAR(64) NOT NULL,
  change_time DATETIME NOT NULL,
  checksum VARBINARY(20) NOT NULL,
  parent_checksum VARBINARY(20) DEFAULT NULL,
  PRIMARY KEY (id),
  INDEX sort_idx (change_time),
  INDEX search_idx (object_name),
  INDEX search_idx2 (object_type(32), object_name(64), change_time),
  INDEX checksum (checksum)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_generated_config (
  id BIGINT(20) UNSIGNED NOT NULL,
  author VARCHAR(64) NOT NULL,
  director_version VARCHAR(64) DEFAULT NULL,
  director_db_version INT(10) DEFAULT NULL,
  duration INT(10) UNSIGNED DEFAULT NULL COMMENT 'Config generation duration (ms)',
  last_activity_checksum VARBINARY(20) NOT NULL,
  checksum VARBINARY(20) NOT NULL COMMENT 'SHA1(file_path=checksum;file_path=checksum;...)',
  ctime DATETIME NOT NULL,
  PRIMARY KEY (id),
  INDEX sort_idx (ctime),
  CONSTRAINT director_generated_config_activity
    FOREIGN KEY activity_checksum (last_activity_checksum)
    REFERENCES director_activity_log (checksum)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_generated_file (
  checksum VARBINARY(20) NOT NULL COMMENT 'SHA1(content)',
  content TEXT NOT NULL,
  PRIMARY KEY (checksum)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_generated_config_file (
  config_id BIGINT(20) UNSIGNED NOT NULL,
  file_checksum VARBINARY(20) NOT NULL,
  file_path VARCHAR(64) NOT NULL COMMENT 'e.g. zones/nafta/hosts.conf',
  CONSTRAINT director_generated_config_file_config
    FOREIGN KEY config (config_id)
    REFERENCES director_generated_config (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT director_generated_config_file_file
    FOREIGN KEY checksum (file_checksum)
    REFERENCES director_generated_file (checksum)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  PRIMARY KEY (config_id, file_path),
  INDEX search_idx (file_checksum)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_deployment_log (
  id BIGINT(20) UNSIGNED AUTO_INCREMENT NOT NULL,
  config_id BIGINT(20) UNSIGNED NOT NULL,
  peer_identity VARCHAR(64) NOT NULL,
  start_time DATETIME NOT NULL,
  end_time DATETIME DEFAULT NULL,
  abort_time DATETIME DEFAULT NULL,
  duration_connection INT(10) UNSIGNED DEFAULT NULL
    COMMENT 'The time it took to connect to an Icinga node (ms)',
  duration_dump INT(10) UNSIGNED DEFAULT NULL
    COMMENT 'Time spent dumping the config (ms)',
  connection_succeeded ENUM('y', 'n') DEFAULT NULL,
  dump_succeeded ENUM('y', 'n') DEFAULT NULL,
  startup_succeeded ENUM('y', 'n') DEFAULT NULL,
  username VARCHAR(64) DEFAULT NULL COMMENT 'The user that triggered this deployment',
  startup_log TEXT DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_datalist (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  list_name VARCHAR(255) NOT NULL,
  owner VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY list_name (list_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_datalist_value (
  list_id INT(10) UNSIGNED NOT NULL,
  value_name VARCHAR(255) DEFAULT NULL,
  value_expression TEXT DEFAULT NULL,
  format enum ('string', 'expression', 'json'),
  PRIMARY KEY (list_id, value_name),
  CONSTRAINT director_datalist_value_datalist
    FOREIGN KEY datalist (list_id)
    REFERENCES director_datalist (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE director_datatype (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  datatype_name VARCHAR(255) NOT NULL,
  -- ?? expression VARCHAR(255) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY datatype_name (datatype_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_zone (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  parent_zone_id INT(10) UNSIGNED DEFAULT NULL,
  object_name VARCHAR(255) NOT NULL,
  object_type ENUM('object', 'template') NOT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name),
  CONSTRAINT icinga_zone_parent_zone
    FOREIGN KEY parent_zone (parent_zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_timeperiod (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_name VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) DEFAULT NULL,
  update_method VARCHAR(64) DEFAULT NULL COMMENT 'Usually LegacyTimePeriod',
  zone_id INT(10) UNSIGNED DEFAULT NULL,
  object_type ENUM('object', 'template') NOT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name, zone_id),
  CONSTRAINT icinga_timeperiod_zone
    FOREIGN KEY zone (zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_timeperiod_range (
  timeperiod_id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  timeperiod_key VARCHAR(255) NOT NULL COMMENT 'monday, ...',
  timeperiod_value VARCHAR(255) NOT NULL COMMENT '00:00-24:00, ...',
  range_type ENUM('include', 'exclude') NOT NULL DEFAULT 'include'
    COMMENT 'include -> ranges {}, exclude ranges_ignore {} - not yet',
  merge_behaviour ENUM('set', 'add', 'substract') NOT NULL DEFAULT 'set'
    COMMENT 'set -> = {}, add -> += {}, substract -> -= {}',
  PRIMARY KEY (timeperiod_id, range_type, timeperiod_key),
  CONSTRAINT icinga_timeperiod_range_timeperiod
    FOREIGN KEY timeperiod (timeperiod_id)
    REFERENCES icinga_timeperiod (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_command (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_name VARCHAR(255) NOT NULL,
  methods_execute VARCHAR(64) DEFAULT NULL,
  command VARCHAR(255) DEFAULT NULL,
  -- env text DEFAULT NULL,
  -- vars text DEFAULT NULL,
  timeout MEDIUMINT(10) UNSIGNED DEFAULT NULL,
  zone_id INT(10) UNSIGNED DEFAULT NULL,
  object_type ENUM('object', 'template', 'external_object') NOT NULL
    COMMENT 'external_object is an attempt to work with existing commands',
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name, zone_id),
  CONSTRAINT icinga_command_zone
    FOREIGN KEY zone (zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_command_argument (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  command_id INT(10) UNSIGNED NOT NULL,
  argument_name VARCHAR(64) DEFAULT NULL COMMENT '-x, --host',
  argument_value TEXT DEFAULT NULL,
  key_string VARCHAR(64) DEFAULT NULL COMMENT 'Overrides name',
  description TEXT DEFAULT NULL,
  skip_key ENUM('y', 'n') DEFAULT NULL,
  set_if VARCHAR(255) DEFAULT NULL, -- (string expression, must resolve to a numeric value)
  sort_order SMALLINT DEFAULT NULL, -- -> order
  repeat_key ENUM('y', 'n') DEFAULT NULL COMMENT 'Useful with array values',
  value_format ENUM('string', 'expression', 'json') NOT NULL DEFAULT 'string',
  set_if_format ENUM('string', 'expression', 'json') DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX sort_idx (command_id, sort_order),
  CONSTRAINT icinga_command_argument_command
    FOREIGN KEY command (command_id)
    REFERENCES icinga_command (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- TODO: icinga_command_allowed_var -> datatype, validator?!
-- icinga_validator
-- icinga_validator_rule

CREATE TABLE icinga_command_var (
  command_id INT(10) UNSIGNED NOT NULL,
  varname VARCHAR(255) DEFAULT NULL,
  varvalue TEXT DEFAULT NULL,
  format ENUM('string', 'expression', 'json') NOT NULL DEFAULT 'string',
  PRIMARY KEY (command_id, varname),
  CONSTRAINT icinga_command_var_command
    FOREIGN KEY command (command_id)
    REFERENCES icinga_command (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_endpoint (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  zone_id INT(10) UNSIGNED NOT NULL,
  object_name VARCHAR(255) NOT NULL,
  address VARCHAR(255) DEFAULT NULL COMMENT 'IP address / hostname of remote node',
  port SMALLINT UNSIGNED NOT NULL DEFAULT 5665,
  log_duration VARCHAR(32) NOT NULL DEFAULT '1d',
  object_type ENUM('object', 'template') NOT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name),
  CONSTRAINT icinga_endpoint_zone
    FOREIGN KEY zone (zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_host (
  id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  object_name VARCHAR(255) NOT NULL,
  address VARCHAR(64) DEFAULT NULL,
  address6 VARCHAR(45) DEFAULT NULL,
  check_command_id INT(10) UNSIGNED DEFAULT NULL,
  max_check_attempts MEDIUMINT UNSIGNED DEFAULT NULL,
  check_period_id INT(10) UNSIGNED DEFAULT NULL,
  check_interval VARCHAR(8) DEFAULT NULL,
  retry_interval VARCHAR(8) DEFAULT NULL,
  enable_notifications ENUM('y', 'n') DEFAULT NULL,
  enable_active_checks ENUM('y', 'n') DEFAULT NULL,
  enable_passive_checks ENUM('y', 'n') DEFAULT NULL,
  enable_event_handler ENUM('y', 'n') DEFAULT NULL,
  enable_flapping ENUM('y', 'n') DEFAULT NULL,
  enable_perfdata ENUM('y', 'n') DEFAULT NULL,
  event_command_id INT(10) UNSIGNED DEFAULT NULL,
  flapping_threshold SMALLINT UNSIGNED default null,
  volatile ENUM('y', 'n') DEFAULT NULL,
  zone_id INT(10) UNSIGNED DEFAULT NULL,
  command_endpoint_id INT(10) UNSIGNED DEFAULT NULL,
  notes TEXT DEFAULT NULL,
  notes_url VARCHAR(255) DEFAULT NULL,
  action_url VARCHAR(255) DEFAULT NULL,
  icon_image VARCHAR(255) DEFAULT NULL,
  icon_image_alt VARCHAR(255) DEFAULT NULL,
  object_type ENUM('object', 'template') NOT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name, zone_id),
  CONSTRAINT icinga_host_zone
    FOREIGN KEY zone (zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_host_check_period
    FOREIGN KEY timeperiod (check_period_id)
    REFERENCES icinga_timeperiod (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_host_check_command
    FOREIGN KEY check_command (check_command_id)
    REFERENCES icinga_command (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_host_event_command
    FOREIGN KEY event_command (event_command_id)
    REFERENCES icinga_command (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_host_command_endpoint
    FOREIGN KEY command_endpoint (command_endpoint_id)
    REFERENCES icinga_endpoint (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_host_inheritance (
  host_id INT(10) UNSIGNED NOT NULL,
  parent_host_id INT(10) UNSIGNED NOT NULL,
  weight MEDIUMINT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (host_id, parent_host_id),
  UNIQUE KEY unique_order (host_id, weight),
  CONSTRAINT icinga_host_inheritance_host
    FOREIGN KEY host (host_id)
    REFERENCES icinga_host (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_host_inheritance_parent_host
    FOREIGN KEY host (parent_host_id)
    REFERENCES icinga_host (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_host_var (
  host_id INT(10) UNSIGNED NOT NULL,
  varname VARCHAR(255) DEFAULT NULL,
  varvalue TEXT DEFAULT NULL,
  format enum ('string', 'json', 'expression'),
  PRIMARY KEY (host_id, varname),
  key search_idx (varname),
  CONSTRAINT icinga_host_var_host
    FOREIGN KEY host (host_id)
    REFERENCES icinga_host (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_service (
  id INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  object_name VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) DEFAULT NULL,
  check_command_id INT(10) UNSIGNED DEFAULT NULL,
  max_check_attempts MEDIUMINT UNSIGNED DEFAULT NULL,
  check_period_id INT(10) UNSIGNED DEFAULT NULL,
  check_interval VARCHAR(8) DEFAULT NULL,
  retry_interval VARCHAR(8) DEFAULT NULL,
  enable_notifications ENUM('y', 'n') DEFAULT NULL,
  enable_active_checks ENUM('y', 'n') DEFAULT NULL,
  enable_passive_checks ENUM('y', 'n') DEFAULT NULL,
  enable_event_handler ENUM('y', 'n') DEFAULT NULL,
  enable_flapping ENUM('y', 'n') DEFAULT NULL,
  enable_perfdata ENUM('y', 'n') DEFAULT NULL,
  event_command_id INT(10) UNSIGNED DEFAULT NULL,
  flapping_threshold SMALLINT UNSIGNED default null,
  volatile ENUM('y', 'n') DEFAULT NULL,
  zone_id INT(10) UNSIGNED DEFAULT NULL,
  command_endpoint_id INT(10) UNSIGNED DEFAULT NULL,
  notes TEXT DEFAULT NULL,
  notes_url VARCHAR(255) DEFAULT NULL,
  action_url VARCHAR(255) DEFAULT NULL,
  icon_image VARCHAR(255) DEFAULT NULL,
  icon_image_alt VARCHAR(255) DEFAULT NULL,
  object_type ENUM('object', 'template', 'apply') NOT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name, zone_id),
  CONSTRAINT icinga_service_zone
    FOREIGN KEY zone (zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_service_check_period
    FOREIGN KEY timeperiod (check_period_id)
    REFERENCES icinga_timeperiod (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_service_check_command
    FOREIGN KEY check_command (check_command_id)
    REFERENCES icinga_command (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_service_event_command
    FOREIGN KEY event_command (event_command_id)
    REFERENCES icinga_command (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT icinga_service_command_endpoint
    FOREIGN KEY command_endpoint (command_endpoint_id)
    REFERENCES icinga_endpoint (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_service_var (
  service_id INT(10) UNSIGNED NOT NULL,
  varname VARCHAR(255) DEFAULT NULL,
  varvalue TEXT DEFAULT NULL,
  format enum ('string', 'json', 'expression'),
  PRIMARY KEY (service_id, varname),
  key search_idx (varname),
  CONSTRAINT icinga_service_var_service
    FOREIGN KEY service (service_id)
    REFERENCES icinga_service (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_host_service (
    host_id INT(10) UNSIGNED NOT NULL,
  service_id INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (host_id, service_id),
  CONSTRAINT icinga_host_service_host
    FOREIGN KEY host (host_id)
    REFERENCES icinga_host (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_host_service_service
    FOREIGN KEY service (service_id)
    REFERENCES icinga_service (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;


--- TODO: service-set

CREATE TABLE icinga_hostgroup (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_name VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name),
  KEY search_idx (display_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_servicegroup (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_name VARCHAR(255) DEFAULT NULL,
  display_name VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name),
  KEY search_idx (display_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_servicegroup_service (
  servicegroup_id INT(10) UNSIGNED NOT NULL,
  service_id INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (servicegroup_id, service_id),
  CONSTRAINT icinga_servicegroup_service_service
    FOREIGN KEY service (service_id)
    REFERENCES icinga_service (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_servicegroup_service_servicegroup
    FOREIGN KEY servicegroup (servicegroup_id)
    REFERENCES icinga_servicegroup (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE icinga_hostgroup_host (
  hostgroup_id INT(10) UNSIGNED NOT NULL,
  host_id INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (hostgroup_id, host_id),
  CONSTRAINT icinga_hostgroup_host_host
    FOREIGN KEY host (host_id)
    REFERENCES icinga_host (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_hostgroup_host_hostgroup
    FOREIGN KEY hostgroup (hostgroup_id)
    REFERENCES icinga_hostgroup (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_hostgroup_parent (
  hostgroup_id INT(10) UNSIGNED NOT NULL,
  parent_hostgroup_id INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (hostgroup_id, parent_hostgroup_id),
  CONSTRAINT icinga_hostgroup_parent_hostgroup
    FOREIGN KEY hostgroup (hostgroup_id)
    REFERENCES icinga_hostgroup (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_hostgroup_parent_parent
    FOREIGN KEY parent (hostgroup_id)
    REFERENCES icinga_hostgroup (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_user (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_name VARCHAR(255) DEFAULT NULL,
  display_name VARCHAR(255) DEFAULT NULL,
  email VARCHAR(255) DEFAULT NULL,
  pager VARCHAR(255) DEFAULT NULL,
  enable_notifications ENUM('y', 'n') DEFAULT NULL,
  period_id INT(10) UNSIGNED DEFAULT NULL,
  zone_id INT(10) UNSIGNED DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name, zone_id),
  CONSTRAINT icinga_user_zone
    FOREIGN KEY zone (zone_id)
    REFERENCES icinga_zone (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_user_filter_state (
  user_id INT(10) UNSIGNED NOT NULL,
  state_name ENUM(
    'OK',
    'Warning',
    'Critical',
    'Unknown',
    'Up',
    'Down'
  ) NOT NULL,
  merge_behaviour ENUM('set', 'add', 'substract') NOT NULL DEFAULT 'set'
    COMMENT 'set: = [], add: += [], substract: -= []',
  PRIMARY KEY (user_id, state_name),
  CONSTRAINT icinga_user_filter_state_user
    FOREIGN KEY icinga_user (user_id)
    REFERENCES icinga_user (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
)  ENGINE=InnoDB;

CREATE TABLE icinga_user_filter_type (
  user_id INT(10) UNSIGNED NOT NULL,
  type_name ENUM(
    'DowntimeStart',
    'DowntimeEnd',
    'DowntimeRemoved',
    'Custom',
    'Acknowledgement',
    'Problem',
    'Recovery',
    'FlappingStart',
    'FlappingEnd'
  ) NOT NULL,
  merge_behaviour ENUM('set', 'add', 'substract') NOT NULL DEFAULT 'set'
    COMMENT 'set: = [], add: += [], substract: -= []',
  PRIMARY KEY (user_id, type_name),
  CONSTRAINT icinga_user_filter_type_user
    FOREIGN KEY icinga_user (user_id)
    REFERENCES icinga_user (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE icinga_user_var (
  user_id INT(10) UNSIGNED NOT NULL,
  varname VARCHAR(255) DEFAULT NULL,
  varvalue TEXT DEFAULT NULL,
  format ENUM('string', 'json', 'expression') NOT NULL DEFAULT 'string',
  PRIMARY KEY (user_id, varname),
  key search_idx (varname),
  CONSTRAINT icinga_user_var_user
    FOREIGN KEY icinga_user (user_id)
    REFERENCES icinga_user (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_usergroup (
  id INT(10) UNSIGNED AUTO_INCREMENT NOT NULL,
  object_name VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) DEFAULT NULL,
  zone_id INT(10) UNSIGNED DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE INDEX object_name (object_name, zone_id),
  KEY search_idx (display_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_usergroup_user (
  usergroup_id INT(10) UNSIGNED NOT NULL,
  user_id INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (usergroup_id, user_id),
  CONSTRAINT icinga_usergroup_user_user
    FOREIGN KEY icinga_user (user_id)
    REFERENCES icinga_user (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_usergroup_user_usergroup
    FOREIGN KEY usergroup (usergroup_id)
    REFERENCES icinga_usergroup (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE icinga_usergroup_parent (
  usergroup_id INT(10) UNSIGNED NOT NULL,
  parent_usergroup_id INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (usergroup_id, parent_usergroup_id),
  CONSTRAINT icinga_usergroup_parent_usergroup
    FOREIGN KEY usergroup (usergroup_id)
    REFERENCES icinga_usergroup (id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT icinga_usergroup_parent_parent
    FOREIGN KEY parent (usergroup_id)
    REFERENCES icinga_usergroup (id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- TODO:
-- apply_rules
-- features
-- implicit ApiListener
-- dependencies
-- notifications
-- scheduled downtimes
