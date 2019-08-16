# Apache Airflow Cloudera CSD ([Custom Service Descriptor](https://github.com/cloudera/cm_ext/wiki/CSD-Overview))

This project allows you to manage and install [Apache Airflow](https://airflow.apache.org/) with [Cloudera Manager](https://www.cloudera.com/products/product-components/cloudera-manager.html).


## Overview
### Architecture
The CSD is comprised of the following roles which can be deployed:

| ROLE | DESCRIPTION |
| --- | --- |
| Gateway | updates the airflow config files found in `/etc/airflow/conf/` |
| Airflow Scheduler | schedules the DAGs found in `CORE_dags_folder` to run on the workers |
| Airflow Webserver | a WebUI used to manage DAGs (multiple instances could be used for redundancy) |
| Airflow Worker | receives tasks from [Celery](http://www.celeryproject.org/) and executes them |
| Airflow Kerberos Renewer | allows workers to interact with a secured hadoop cluster by regularly renewing a kerberos ticket from a keytab |
| Airflow Celery Flower | a WebUI used to monitor the Celery cluster ([see docs](https://flower.readthedocs.io/en/latest/)) |

### Download
| Airflow Version | CSD |
|---|---|
| 1.10.3 | [AIRFLOW-1.10.3.jar](https://teamclairvoyant.s3.amazonaws.com/apache-airflow/cloudera/csd/AIRFLOW-1.10.3.jar) |

### Requirements
- Cloudera Manger:
  - \>=5.13.0
- Operating Systems:
  - CentOS / RHEL 6
  - CentOS / RHEL 7
  - Ubuntu 14.04
  - Ubuntu 16.04
  - Ubuntu 18.04
- A NAS mount present on all nodes:
  - Used for `CORE_dags_folder`
- A Metadata Database:
  - [PostgreSQL](https://www.postgresql.org/)
  - [MySQL](https://www.mysql.com/)
- A Celery Broker Backend:
  - [RabbitMQ](https://www.rabbitmq.com/) *(Recommenced)*
  - [Redis](https://redis.io/)
  - [PostgresSQL](https://www.postgresql.org/) *(Testing Only)*
  - [MySQL](https://www.mysql.com/) *(Testing Only)*
- A Celery Result Backend:
  - [Redis](https://redis.io/) *(Recommenced)*
  - [PostgresSQL](https://www.postgresql.org/)
  - [MySQL](https://www.mysql.com/)

### Known Issues
**Feature:**
1. After changing configs in Cloudera Manager, you will not be warned that you need to restart roles.
1. In the configuration wizard (when first adding the Airflow service), configs are displayed in a random order which can make it difficult to see which configs are related to each other. (If you make a mistake in the wizard, the configuration page of the resulting Airflow service has the correct config order)
1. The RBAC UI is not properly supported (`WEBSERVER_rbac == true`), as we don't yet template `AIRFLOW_HOME/webserver_config.py`. This means you will only be able to use a password based authentication, creating users as [described here](#3---creating-webui-users).

**Security:**
1. The Airflow Celery Flower role will expose the connection string of the Celery broker. Any user on the same server can run `ps -aux | grep /bin/flower` and the connection string will be visible. **If this is a concern to you DO NOT deploy any Airflow Celery Flower roles!**
1. Sensitive environment variables will not necessarily be redacted in the 'Cloudera Manager' --> 'Instances' --> 'Processes' UI, this is because Airflow uses variables like `AIRFLOW__CORE__FERNET_KEY` and `AIRFLOW__CORE__SQL_ALCHEMY_CONN` which do not contain the word 'password'.


## Setup Guide
### 1 - Install CSD JAR
1. Download the CSD jar for your chosen version of Airflow.
1. Copy the jar file to `/opt/cloudera/csd` on the Cloudera Manager server.
1. Restart the Cloudera Manager Server service. `service cloudera-scm-server restart`

### 2 - Install Airflow Parcel
1. Follow the usage information for the [Apache Airflow Cloudera Parcel](https://github.com/teamclairvoyant/apache-airflow-cloudera-parcel).

### 3 - Prepare Metadata Database
Airflow needs a database to store metadata about DAG runs, you can use PostgreSQL or MySQL for this purpose.

**Basic Setup:**
1. A database needs to be created for airflow.
1. An airflow user needs to be created along with a password.
1. Grant all the privileges on the database to the newly created user.

**Example -- MySQL:**
1. Create a database:
    ```SQL
    CREATE DATABASE airflow DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
    ```
1. Create a new user and grant privileges on the database:
    ```SQL
    GRANT ALL ON airflow.* TO 'airflow'@'localhost' IDENTIFIED BY '{{AIRFLOWDB_PASSWORD}}';
    GRANT ALL ON airflow.* TO 'airflow'@'%' IDENTIFIED BY '{{AIRFLOWDB_PASSWORD}}';
    ```

**Example -- PostgreSQL:**
1. Create a role:
    ```SQL
    CREATE ROLE airflow LOGIN ENCRYPTED PASSWORD '{{AIRFLOWDB_PASSWORD}}' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;
    ALTER ROLE airflow SET search_path = airflow, "$user", public;
    ```
1. Create a database:
    ```SQL
    CREATE DATABASE airflow WITH OWNER = airflow ENCODING = 'UTF8' TABLESPACE = pg_default CONNECTION LIMIT = -1;
    ```

### 4 - Prepare Celery Broker Backend
You will need to setup a broker backend for Celery to preform message transport. Celery is able to use any of the following:
- [RabbitMQ](https://www.rabbitmq.com/) *(Recommenced)*
- [Redis](https://redis.io/)
- [PostgresSQL](https://www.postgresql.org/) *(Testing Only)*
- [MySQL](https://www.mysql.com/) *(Testing Only)*

### 5 - Prepare Celery Result Database
You will need to setup a result database for Celery. Celery is able to use any of the following:
- [Redis](https://redis.io/) *(Recommenced)*
- [PostgresSQL](https://www.postgresql.org/)
- [MySQL](https://www.mysql.com/)

### 6 - Deploy Airflow Service
To begin setting up the Airflow service, go to 'Cloudera Manager' --> 'Add Service' --> 'Airflow'. 

### 6.1 - Role Provisioning
Roles need to be assigned to nodes according to the following rules:

| ROLE | REQUIREMENT |
| --- | --- |
| Gateway | `all nodes` |
| Airflow Scheduler | `exactly one node` |
| Airflow Webserver | `at least one node` |
| Airflow Kerberos Renewer | `all worker nodes`<br>(in a secured hadoop cluster) | 
| Airflow Celery Flower | `any number` |

### 6.2 - Service Configuration

#### 6.2.1 - Basic Configs
These properties should be customised by all airflow deployments:

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `CORE_dags_folder` | /mnt/airflow/dags | a location which is accessible from all nodes to store DAG .py files (typically this is an NFS mount) |
| `CORE_fernet_key` | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx= | a secret key to encrypt connection passwords in the metadata db ([see here](https://airflow.apache.org/howto/secure-connections.html)) |
| `WEBSERVER_secret_key` | xxxxxx | a secret key used by your flask app for the WebUI |
| `WEBSERVER_base_url` | http://XXXXX:8080 | the base url of the WebUI, used for automated emails to link to the correct webserver |
| `WEBSERVER_web_server_port` | 8080 | the port to run the WebUI on |

#### 6.2.2 - Database Configs
These properties are needed by all airflow deployments, and specify how airflow will connect to your metadata database which was prepared in [step 3](#3---prepare-metadata-database):

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `CORE_db_type` | postgresql | the type of the database to be used |
| `CORE_db_host` | XXXXXX | the hostname or IP of the database |
| `CORE_db_port` | 5432 | the port of the database |
| `CORE_db_name` | airflow | the name of the database to be used |
| `CORE_db_username` | airflow | the username to authenticate with the database |
| `CORE_db_password` | XXXXXX | the password to authenticate with the database |

These variables are combined into the environment variable `AIRFLOW__CORE__SQL_ALCHEMY_CONN` as you start roles:
>${CORE_db_type}://${CORE_db_username}:${CORE_db_password}@${CORE_db_host}:${CORE_db_port}/${CORE_db_name}

#### 6.2.3 - Celery Broker Configs
These properties are needed by all airflow deployments, and specify how airflow will connect to your Celery broker backend which was prepared in [step 4](#4---prepare-celery-broker-backend):

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `CELERY_broker_type` | amqp (RabbitMQ) | the type of the database to be used |
| `CELERY_broker_host` | XXXXXX | the hostname or IP of the database |
| `CELERY_broker_port` | 5672 | the port of the database | 
| `CELERY_broker_db_name` | airflow | the name of the database to be used (only needed for actual database types) |
| `CELERY_broker_username` | airflow | the username to authenticate with the database |
| `CELERY_broker_password` | XXXXXX | the password to authenticate with the database |

These variables are combined into the environment variable `AIRFLOW__CELERY__BROKER_URL` as you start roles:
>${CELERY_broker_type}://${CELERY_broker_username}:${CELERY_broker_password}@${CELERY_broker_host}:${CELERY_broker_port}/${CELERY_broker_db_name}

#### 6.2.4 - Celery Result Backend Database Configs
These properties are needed by all airflow deployments, and specify how airflow will connect to your Celery result database which was prepared in [step 5](#5---prepare-celery-result-database):

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `CELERY_result_db_type` | db+postgresql | the type of the database to be used |
| `CELERY_result_db_host` | XXXXXX | the hostname or IP of the database |
| `CELERY_result_db_port` | 5432 | the port of the database |
| `CELERY_result_db_name` | airflow | the name of the database to be used |
| `CELERY_result_db_username` | airflow | the username to authenticate with the database |
| `CELERY_result_db_password` | XXXXXX | the password to authenticate with the database |

These variables are combined into the environment variable `AIRFLOW__CELERY__RESULT_BACKEND` as you start roles:
>${CELERY_result_db_type}://${CELERY_result_db_username}:${CELERY_result_db_password}@${CELERY_result_db_host}:${CELERY_result_db_port}/${CELERY_result_db_name}


#### 6.2.5 - Final Steps
1. In 'Cloudera Manager' --> 'Airflow' -- 'Actions' run 'Initialize Airflow DB'
1. In 'Cloudera Manager' --> 'Airflow' -- 'Actions' run 'Start'

### 6.3 - (Optional) Secure/Kerberized Cluster Setup
If your Cloudera Cluster is secured/kerberized, make sure you deploy the 'Airflow Kerberos Renewer' role to every worker node.
After this, generate a keytab and place it at a location which is visible on all of these nodes (for example a NFS server).

Once you have done this, configure the following properties under 'Cloudera Manager' --> 'Airflow' --> 'Configuration':

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `CORE_security` | kerberos | this config must be set to 'kerberos' |
| `KERBEROS_principal` | airflow_user | the principal to initialize (must be present in the keytab) |
| `KERBEROS_keytab` | /mnt/secure/airflow.keytab | the path of the keytab file (must be present on all nodes) |

### 6.4 - (Optional) Email/SMTP Setup
To allow Airflow to send emails, you must configure the following SMTP settings:

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `SMTP_smtp_host` | mailhost.example.com | the IP or hostname of the SMTP server |
| `SMTP_smtp_port` | 25 | the port of the SMTP server |
| `SMTP_smtp_starttls` | false | if STARTTLS should be used with the SMTP server |
| `SMTP_smtp_ssl` | false | if SSL should be used with the SMTP server |
| `SMTP_smtp_user` | | the username to authenticate with the SMTP server (specify if you want to use SMTP AUTH) |
| `SMTP_smtp_password` | | the password to authenticate with the SMTP server |
| `SMTP_smtp_mail_from` | airflow@example.com | the email to send from |

### 6.5 - Authentication Setup
To protect the WebUI behind a password, you have a few options, depending on if you enable `WEBSERVER_rbac` or not.

#### 6.5.1 - RBAC off

When `WEBSERVER_rbac == false` you can use the following configuration properties:

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `WEBSERVER_authenticate` | true | must be 'true' to enable authentication with RBAC off |
| `WEBSERVER_auth_backend` | airflow.contrib.auth.backends.password_auth | the authentication backend class to use with RBAC off |

If you specified `WEBSERVER_auth_backend == airflow.contrib.auth.backends.ldap_auth`, you must configure the following properties:

| PROPERTY | EXAMPLE | DESCRIPTION |
| --- | --- | --- |
| `LDAP_uri` | ldaps://example.com:1234 | the URI of your LDAP server |
| `LDAP_user_filter` | objectClass=* | a filter for entities under `LDAP_basedn` |
| `LDAP_user_name_attr` | sAMAccountName | the entity attribute for user name (sAMAccountName is used for AD) |
| `LDAP_group_member_attr` | memberOf | the attribute name for being a member of a group |
| `LDAP_superuser_filter` | memberOf=CN=airflow-super-users,OU=Groups,DC=example,DC=com | a filter for which users to give superuser permissions (leave empty to give all users) |
| `LDAP_data_profiler_filter` | memberOf=CN=airflow-data-profilers,OU=Groups,DC=example,DC=com | a filter for which users to give data profiler permissions (leave empty to give all users) |
| `LDAP_bind_user` | cn=Manager,dc=example,dc=com | the simple bind username (leave blank for anonymous) |
| `LDAP_bind_password` | XXXXXX | the simple bind password (leave blank for anonymous) |
| `LDAP_basedn` | dc=example,dc=com | the domain path to search for entities within |
| `LDAP_cacert` | /etc/ca/ldap_ca.crt | the path of a CA certificate (leave empty if none) |
| `LDAP_search_scope` | SUBTREE | how to search for entities (use SUBTREE for AD) |
| `LDAP_ignore_malformed_schema` | false | if malformed LDAP schemas should be ignored |

**NOTE:** airflow only supports simple bind authentication (or anonymous) with LDAP, not GSSAPI.

#### 6.5.2 - RBAC on

When `WEBSERVER_rbac == true` we only allow for password based authentication, (suppot for LDAP could be added if needed).
To add new users, follow the [guide here](#3---creating-webui-users).


## Usage Guide
### 1 - Scheduling DAGs
- To schedule a DAG, you place a .py file inside the folder specified by `CORE_dags_folder`:
  - This folder should be visible on all nodes (and is likely a NAS which has been mounted on all nodes)
  - A common approach is to store your DAG code in a git repo, and regularly sync this repo into the `CORE_dags_folder` with an Airflow job

### 2 - Airflow CLI
The `airflow` command is added to all nodes by the Airflow Parcel.
To use this command on a node, you must export some environment variables describing your Airflow install:
```bash
export AIRFLOW_HOME=/var/lib/airflow
export AIRFLOW_CONFIG=/etc/airflow/conf/airflow.cfg
export AIRFLOW__CORE__SQL_ALCHEMY_CONN={{CORE_db_type}}://{{CORE_db_username}}:{{CORE_db_password}}@{{CORE_db_host}}:{{CORE_db_port}}/{{CORE_db_name}}
```

#### 2.1 - Checking DAGs
To verify that DAGS are visible to airflow, you can run the following command:
```bash
# dont forget to export the needed environment variables
export ...

airflow list_dags
```

#### 2.2 - Other Commands
For a complete list of Airflow commands refer to the [Airflow Command Line Interface](https://airflow.apache.org/cli.html).

### 3 - Creating WebUI Users
When `WEBSERVER_rbac == true`, you have two options for creating new users, you can use the Airflow CLI, or use the WebUI (if you already created an admin account).

**Example -- Airflow CLI:**
```bash
# dont forget to export the needed environment variables
export ...

# create user 'admin' (prompting for password)
airflow create_user --role Admin --username admin --email null@null --firstname admin --lastname admin
```

**Example -- WebUI:**
1. Login to the WebUI with an 'Admin' role account
1. Navigate to the 'Security' -->  'List Users' tab from the dropdown
1. Click the '+' and create the user with the form


## Contributing Guide
### How to build?
```bash
git clone https://github.com/teamclairvoyant/apache-airflow-cloudera-csd
cd apache-airflow-cloudera-csd
mvn clean package
```

### Where are some CSD Resources?
1. https://github.com/cloudera/cm_ext/wiki/The-Structure-of-a-CSD
1. https://github.com/cloudera/cm_ext/wiki/Service-Descriptor-Language-Reference
1. https://github.com/cloudera/cm_csds
