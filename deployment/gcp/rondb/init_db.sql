
create user 'hop'@'%' identified by 'hop';
grant all privileges on *.* to 'hop'@'%';
flush privileges;

CREATE DATABASE flinkndb;
USE flinkndb;

CREATE TABLE `key_value_state` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `epoch` bigint NOT NULL,
    value varbinary(8000) not null,
PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `key_value_state_committed` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `epoch` bigint NOT NULL,
    value varbinary(8000) not null,
    PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`,`epoch`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `key_value_state_snapshot` (
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    `status` int(11) not null,
    PRIMARY KEY (`keygroup_id`,`namespace`,`epoch`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `list_value_state` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `list_index` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    `value` varbinary(8000) not null,
    PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`,`list_index`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `list_value_state_committed` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `list_index` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    `value` varbinary(8000) not null,
    PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`,`list_index`, `epoch`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `list_key_value_state_snapshot` (
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    `status` int(11) not null,
    PRIMARY KEY (`keygroup_id`,`namespace`,`epoch`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `list_state_attrib` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `list_length` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `list_state_attrib_committed` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `list_length` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`, `epoch`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `map_key_value_state` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `user_key` int(11) NOT NULL,
    `user_key_ser` varbinary(5000) NOT NULL,
    `value` varbinary(8000) NOT NULL,
    `epoch` bigint NOT NULL,
PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`,`user_key`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `map_key_value_state_committed` (
    `key` int(11) NOT NULL,
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `state_name` varchar(500) NOT NULL,
    `epoch` bigint NOT NULL,
    `user_key` int(11) NOT NULL,
    `user_key_ser` varbinary(5000) NOT NULL,
    `value` varbinary(8000) not null,
    PRIMARY KEY (`key`,`keygroup_id`,`namespace`,`state_name`,`epoch`, `user_key`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);

CREATE TABLE `map_key_value_state_snapshot` (
    `keygroup_id` int(11) NOT NULL,
    `namespace` int(11) NOT NULL,
    `epoch` bigint NOT NULL,
    `status` int(11) not null,
    PRIMARY KEY (`keygroup_id`,`namespace`,`epoch`)
) ENGINE=ndbcluster DEFAULT CHARSET=latin1
    PARTITION BY KEY (keygroup_id);