#!/bin/sh
# NodeBB

CUR_DIR=$(cd "$(dirname "$0")";pwd)
CUR_SCRIPT_NAME="${0##*/}"

DIR_BACKUP="$CUR_DIR/nodebb_backup"
NODEBB_PATH="$CUR_DIR/repo"
REDIS_CLI=''

LINE_1="-------------------------------------------------------------------"

err_exit() {
  [ -z "$1" ] || echo "$1"
  exit
}

nodebb_database_check() {
  cat $NODEBB_PATH/config.json|grep -Eo 'database.*redis' &>/dev/null && DATABASE='redis'
  cat $NODEBB_PATH/config.json|grep -Eo 'database.*mangodb' &>/dev/null && DATABASE='mangodb'
}

redis_dump() {
  REDIS_CONF=$(find /etc|grep redis.conf|head -n1)
  [ -z "$REDIS_CONF" ] && err_exit "Could not find redis.conf"
  REDIS_DB_PATH=$(cat "$REDIS_CONF"|grep -Eoi '^dir\s+.*'|sed -E 's/^dir\s+//')
  [ -z "$REDIS_DB_PATH" ] && err_exit "Not set redis db path"
  REDIS_DB_NAME=$(cat "$REDIS_CONF"|grep -Eoi '^dbfilename\s+.*'|sed -E 's/^dbfilename\s+//')
  [ -z "REDIS_DB_NAME" ] && REDIS_DB_NAME='dump.rdb'
  REDIS_DB_PATH="$REDIS_DB_PATH/$REDIS_DB_NAME"
  which redis-cli &>/dev/null || err_exit "Not found command redis-cli."
  REDIS_CONNECT="redis-cli $REDIS_CLI"
  echo "BGSAVE" | $REDIS_CONNECT
  echo "Backup Redis Database" && sleep 10
  try=6
  while [ $try -gt 0 ] ; do
    bg=$(echo 'info Persistence' | $REDIS_CONNECT | awk -F: '/rdb_bgsave_in_progress/{sub(/\r/, "", $0); print $2}')
    ok=$(echo 'info Persistence' | $REDIS_CONNECT | awk -F: '/rdb_last_bgsave_status/{sub(/\r/, "", $0); print $2}')
    if [ "$bg" = "0" -a "$ok" = "ok" ] ; then
      [ -f "$REDIS_DB_PATH" ] || return 1
      REDIS_VER=$(echo 'info Server' | $REDIS_CONNECT | awk -F: '/redis_version/{sub(/\r/, "", $0); print $2}')
      REDIS_OK=1 && try=0 && echo "- Dump redis ... OK"
    else
      sleep 10
    fi
    try=$((try - 1))
  done
  [ "$REDIS_OK" = "1" ] && return 0
  echo "- Dump redis ... Failed"
  return 1
}

backup_redis() {
  redis_dump || return 1
  BACKUP_TIME=$(date +%Y%m%d%H%M)
  [ -d "$DIR_BACKUP" ] || mkdir -p "$DIR_BACKUP"
  DB_BACKUP_NAME="redis-$REDIS_VER-$BACKUP_TIME.rdb"
  cp -f "$REDIS_DB_PATH" "$DIR_BACKUP/$DB_BACKUP_NAME"
  echo "[SUCCESS] Redis DB has been backup to \"$DIR_BACKUP/$DB_BACKUP_NAME\""
}

backup_uploads() {
  BACKUP_TIME=$(date +%Y%m%d%H%M)
  [ -d "$NODEBB_PATH/public/uploads" ] || err_exit "NodeBB uploads does not exist."
  [ -d "$DIR_BACKUP" ] || mkdir -p "$DIR_BACKUP"
  tar -zcf "$DIR_BACKUP/uploads-$BACKUP_TIME.tar.gz" -C "$NODEBB_PATH/public" uploads &>/dev/null || return 1
  echo "Backup uploads ... OK"
  echo "- \"$DIR_BACKUP/uploads-$BACKUP_TIME.tar.gz\""
}

backup_modules() {
  BACKUP_TIME=$(date +%Y%m%d%H%M)
  [ -d "$NODEBB_PATH/node_modules" ] || err_exit "node_modules does not exist."
  tar -zcf "$DIR_BACKUP/node_modules-$BACKUP_TIME.tar.gz" -C "$NODEBB_PATH" node_modules &>/dev/null || return 1
  echo "Backup node_modules ... OK"
  echo "- \"$DIR_BACKUP/node_modules-$BACKUP_TIME.tar.gz\""
}

nodebb_last_release() {
  UPDATE='0'
  FILE_EXT='.zip'
  LAST_RELEASE_URL=$(wget -O- -q https://github.com/NodeBB/NodeBB/releases|grep -o '\/[^"]*archive\/[^"]*\.[^"]*'|grep "$FILE_EXT"|head -n1)
  LAST_RELEASE_URL="https://github.com$LAST_RELEASE_URL"
  LAST_RELEASE_VERSION="${LAST_RELEASE_URL##*/}"
  FILE_NAME="$LAST_RELEASE_VERSION"
  LAST_RELEASE_VERSION="${LAST_RELEASE_VERSION%$FILE_EXT*}"
  [ -z "$LAST_RELEASE_VERSION" ] && err_exit "Could not get NodeBB last release."
  INSTALLED_VERSION=$(cat "$NODEBB_PATH/logs/output.log" |grep -oi '^nodebb\sv[0-9]\+\(\.[0-9]\+\)*'|tail -n1|grep -oi 'v.*')
  [ -z "$INSTALLED_VERSION" ] && err_exit "Could not get NodeBB last installed version."
  if [ "$INSTALLED_VERSION" = "$LAST_RELEASE_VERSION" ]; then
    echo "Nodebb is up to data."
    return 1
  else
    echo "Nodebb Update"
    echo "Installed:      $INSTALLED_VERSION"
    echo "Last release:   $LAST_RELEASE_VERSION"
    return 0
  fi
}

nodebb_update() {
  nodebb_last_release || err_exit
  echo "Updating, please wait..."
  wget -O "$CUR_DIR/$FILE_NAME" "$LAST_RELEASE_URL" || err_exit "Failed to download $$LAST_RELEASE_URL."
  unzip "$FILE_NAME" -d "$CUR_DIR/nodebb_update" &>/dev/null || return 1
  UPDATE_TEMP="$CUR_DIR/nodebb_update/"$(ls -1 ${CUR_DIR}/nodebb_update|head -n1)
  $NODEBB_PATH/nodebb stop
  cp -rf "$NODEBB_PATH/node_modules" "$UPDATE_TEMP"
  cp -rf "$NODEBB_PATH/public/uploads" "$UPDATE_TEMP/public"
  cp -f "$NODEBB_PATH/config.json" "$UPDATE_TEMP"
  rm -rf "$NODEBB_PATH" 
  ls -a "$UPDATE_TEMP"|grep -Eo '^\.\w.*'|while read LINE
  do
    rm -rf "$UPDATE_TEMP/$LINE"
  done
  cp -rf "$UPDATE_TEMP"/* "$NODEBB_PATH" &>/dev/null
  # cp -rf "$UPDATE_TEMP"/.* "$NODEBB_PATH" &>/dev/null
  cd "$NODEBB_PATH"
  ./nodebb upgrade
  ./nodebb start
  cd "$CUR_DIR"
  rm -rf "$CUR_DIR/nodebb_update"
  rm -f "$CUR_DIR/$FILE_NAME"
  echo "Nodebb Update ... OK"
  echo "[UPDATE] Version $LAST_RELEASE_VERSION"
}

nodebb_backup() {
  echo "Bckup Nodebb"
  redis_dump || return 1
  mkdir -p "$CUR_DIR/nodebb_tmp/repo/public" || err_exit "Could not create tmp folder."
  cp -f "$REDIS_DB_PATH" "$CUR_DIR/nodebb_tmp/dump.redis.$REDIS_VER.$BACKUP_TIME.rdb"
  cp -rf "$NODEBB_PATH/node_modules" "$CUR_DIR/nodebb_tmp/repo"
  echo "Bakcup node_moules ... OK"
  cp -rf "$NODEBB_PATH/public/uploads" "$CUR_DIR/nodebb_tmp/public"
  echo "Bakcup uploads ... OK"
  cp -f "$NODEBB_PATH/config.json" "$CUR_DIR/nodebb_tmp/repo"
  echo "Bakcup config.json ... OK"
  BACKUP_TIME=$(date +%Y%m%d%H%M)
  [ -d "$DIR_BACKUP" ] && mkdir -p "DIR_BACKUP"
  tar -zcf "$DIR_BACKUP/nodebb-BACKUP_TIME.tar.gz" -C "$CUR_DIR/nodebb_tmp" . || err_exit "Failed to generate backup file."
  echo "Build backup file ... OK"
  rm -rf "$CUR_DIR/nodebb_tmp"
  echo "[BACKUP] $DIR_BACKUP/nodebb-BACKUP_TIME.tar.gz"
}

case $1 in
  redis)
    backup_redis
    ;;
  uploads)
    backup_uploads
    ;;
  modules)
    backup_modules
    ;;
  update)
    nodebb_update
    ;;
  backup)
    nodebb_backup
    ;;
  last)
    nodebb_last_release
    ;;
  *)
    echo "USAGE:"
    echo "./nbb.sh [ redis | uploads | modules | backup| last | update ]"
    echo "- redis        Backup redis database"
    echo "- uploads      Backup uploads folder"
    echo "- modules      Backup node_modules folder"
    echo "- backup       Backup database and uploads, node_modules"
    echo "- last         Get last release"
    echo "- update       Update to last release"
    ;;
esac

