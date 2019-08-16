#!/usr/bin/env bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2019
#
unset PYTHONPATH
unset PYTHONHOME

. $(cd $(dirname $0) && pwd)/common.sh

case $1 in
  (deploy_client_config)
    bash_deploy_client_config
    ;;

  (initialize_db_backend)
    bash_initialize_db_backend
    ;;

  (upgrade_db_backend)
    bash_upgrade_db_backend
    ;;

  (start_scheduler)
    bash_start_scheduler
    ;;

  (start_webserver)
    bash_start_webserver
    ;;

  (start_worker)
    bash_start_worker
    ;;

  (start_kerberos_renewer)
    bash_start_kerberos_renewer
    ;;

  (start_celery_flower)
    bash_start_celery_flower
    ;;

  (*)
    log "Don't understand [$1]"
    exit 1
    ;;
esac
