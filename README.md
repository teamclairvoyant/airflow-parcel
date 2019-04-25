# Airflow Custom Service Descriptor ([CSD](https://github.com/cloudera/cm_ext/wiki/CSD-Overview#custom-service-descriptors))

This repository allows you to install [Apache Airflow](https://airflow.apache.org/) as a service managable by [Cloudera Manager](https://www.cloudera.com/products/product-components/cloudera-manager.html).

## Requirements
- A supported operating system.
- MySQL or PostgreSQL database in which to store Airflow metadata.
- [Airflow](https://github.com/teamclairvoyant/apache-airflow-parcels) and [RabbitMQ](https://github.com/teamclairvoyant/rabbitmq-cloudera-parcel) parcels need to be installed.

### Currently Supported Versions of Airflow
- Airflow 1.7.1.3
- Airflow 1.8.0

### Currently Supported Operating Systems
- CentOS 6 & 7
- RHEL 6 & 7

## Installing the CSD
1. Download the Jar file.  [Airflow CSD](https://teamclairvoyant.s3.amazonaws.com/apache-airflow/cloudera/csd/AIRFLOW-1.8.0.jar)
2. Copy the jar file to the `/opt/cloudera/csd` location on the Cloudera Manager server.
3. Restart the Cloudera Manager Server service. `service cloiudera-scm-server restart`

## Requirements
1. A database needs to be created.
2. A database user needs to be created along with a password.
3. Grant all the privileges on the database to the newly created user.
4. Set `AIRFLOWDB_PASSWORD` to a sufficient value. For example, run the following in your Linux shell session: `< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`

Example for MySQL:
1. Create a database.
   ```SQL
   CREATE DATABASE airflow DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
   ```
2. Create a new user and grant privileges on the database.
   ```SQL
   GRANT ALL ON airflow.* TO 'airflow'@'localhost' IDENTIFIED BY 'AIRFLOWDB_PASSWORD';
   GRANT ALL ON airflow.* TO 'airflow'@'%' IDENTIFIED BY 'AIRFLOWDB_PASSWORD';
   ```
Alternatively, you can use the [Airflow/MySQL deployment script](https://github.com/teamclairvoyant/hadoop-deployment-bash/blob/master/services/create_mysql_dbs-airflow.sh) to create the MySQL database using:
```bash
create_mysql_dbs-airflow.sh --host <host_name> --user <username> --password <password>
```

Example for PostgreSQL:
1. Create a role.
   ```SQL
   CREATE ROLE airflow LOGIN ENCRYPTED PASSWORD 'AIRFLOWDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;
   ALTER ROLE airflow SET search_path = airflow, "$user", public;
   ```
2. Create a database.
   ```SQL
   CREATE DATABASE airflow WITH OWNER = airflow ENCODING = 'UTF8' TABLESPACE = pg_default CONNECTION LIMIT = -1;
   ```
Alternatively, you can use the [Airflow/PostgreSQL deployment script](https://github.com/teamclairvoyant/hadoop-deployment-bash/blob/master/services/create_postgresql_dbs-airflow.sh) to create the PostgreSQL database using:
```bash
create_postgresql_dbs-airflow.sh --host <host_name> --user <username> --password <password>
```

## Roles
There are seven roles defined in the CSD.
1. Airflow Webserver
2. Airflow Scheduler
3. Airflow Worker
4. Airflow Flower

Airflow Webserver: Airflow Webserver role is used to start the Airflow Web UI. Webserver role can be deployed on more than instances. However, they will be the same and can be used for backup purposes.

Airflow Scheduler: Airflow Scheduler role is used to schedule the Airflow jobs. This is limited to one instance to reduce the risk of duplicate jobs.

Airflow Worker: Airflow Worker role picks jobs from RabbitMQ and executed them on the nodes. Multiple instances can be deployed.

Airflow Flower: Airflow Flower is used to monitor  celery clusters. Multiple instances are supported

## Using the Airflow binary:
Here are some of the examples of Airflow commands:

### Listing Airflow DAGs:
```bash
airflow list_dags
```

### Manually triggering a DAG:
The dag file has to be copied to all the nodes to the dags folder manually.
```bash
airflow trigger_dag <DAG Name>
```

For a complete list of Airflow commands refer to the [Airflow Command Line Interface](https://airflow.apache.org/cli.html).

## Deploying a DAG:
The DAG file has to be copied to `dags_folder` directory within all the nodes. It is important to manually distribute to all the nodes where the roles are deployed.

## Enabling Authentication for Airflow Web UI:
In order to enable authentication for the Airflow Web UI check the "Enable Airflow Authentication" option. You can create Airflow users using one of two options below.

### Creating Airflow Users using UI:
1. Navigate to Airflow CSD. In the configurations page, enter the Airflow Username, Airflow Email, Airflow Password you want to create.
2. Deploy the client configurations to create the Airflow user.

Note: Although the last created user shows up in the Airflow configurations, you can still use the previously created users.

### Using mkuser.sh
Another way to add Airflow users is using the `mkuser.sh` script.  Users can be added as follows:
1. Navigate to the current working directory of the CSD under `/var/run/cloudera-scm-agent/process`
2. Export PYTHONPATH and AIRFLOW_HOME environment variables. By default these are:

   PYTHONPATH:
   ```bash
   export PYTHONPATH=/opt/cloudera/parcels/AIRFLOW/usr/lib/python2.7/site-packages:$PYTHONPATH
   ```
   Airflow Home:
   ```bash
   export AIRFLOW_HOME=/var/lib/airflow
   ```
3. Within the scripts directory, you can find the `mkuser.py` file. Execute `mkuser.py` to add a user to Airflow:
   ```bash
   /opt/cloudera/parcels/AIRFLOW/bin/python2.7 mkuser.py <Username> <UserEmail> <Password>
   ```
   For example, this can be like
   ```bash
   /opt/cloudera/parcels/AIRFLOW/usr/bin/python2.7 mkuser.py airflowUser airflow@email.com airflowUserPassword
   ```

## Building the CSD
```bash
git clone https://github.com/teamclairvoyant/apache-airflow-cloudera-csd
cd apache-airflow-cloudera-csd
mvn clean package
```
or
```bash
java -jar target/validator.jar -s src/descriptor/service.sdl
jar -cvf AIRFLOW-1.0.0.jar -C src/ .
```

## Limitations:
1. Number of RabbitMQ instances is limited to 1.
2. The IP address of the RabbitMQ instance has to be manually entered during installation configuration.
3. After deploying configurations, there is no alert or warning that the specific roles needs to be restarted.
4. Only 'airflow.contrib.auth.backends.password_auth' mechanism is supported for Airflow user authentication.

## Future work:
1. RabbitMQ needs to installed in Cluster Mode.
2. Test Database connection.
3. Add the support for more Airflow user authentication methods.

## Known Errors:

### Markup already exists Error:

Upon many deployments, you may face an error called 'Markup file already exists' while trying to stop a role and the process never stops. In that case, stop the process using the "Abort" command and navigate to `/var/run/cloudera-scm-agent/process` and delete all the `GracefulRoleStopRunner` directories.

### Lag in DAG Execution:

Occasionally, we experienced some delay in DAG execution. We are working to fix this.

## Resources:
1. https://github.com/cloudera/cm_ext/wiki/The-Structure-of-a-CSD
2. https://github.com/cloudera/cm_ext/wiki/Service-Descriptor-Language-Reference
3. https://github.com/cloudera/cm_csds

