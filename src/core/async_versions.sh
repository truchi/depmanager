# shellcheck shell=bash
# shellcheck source=../vars.sh
. ""

#
# Returns async_versions array key for manager $1, package $2 (optional), type $3 (local/remote, optional)
#
async_versions.key() {
  local manager="$1"
  local package="$2"
  local type="$3"

  local key="manager___${manager}___"
  string.is_empty "$package" || key+="package___${package}___"
  string.is_empty "$type"    || key+="type___${type}___"

  echo "$key"
}

#
# Creates a new fifo named $1
#
async_versions.fifo.new() {
  local fifo="$1"

  # Deletes if exists
  [ -p "$fifo" ] && rm "$fifo"

  # Creates new fifo
  mknod "$fifo" p
}

#
# Returns the fifo name for manager $1, package $2 (optional)
#
async_versions.fifo.name() {
  local manager="$1"
  local package="$2"

  local fifo="$DEPMANAGER_CACHE_DIR/fifo__${manager}"
  string.is_empty "$package" || fifo+="__${package}"

  echo "$fifo"
}

#
# Reads fifo named $1, $2 times, and writes in async_versions array
#
async_versions.fifo.read() {
  local fifo="$1"
  local count="$2"

  # Infinite loop (the only way to make this work properly?)
  local i=0
  while true; do
    local data
    local array

    # Read fifo
    read -r data
    ! helpers.is_set "$data" && continue

    # Read data
    IFS=, read -r -a array <<< "$data"
    async_versions["${array[0]}"]="${array[1]}"

    i=$((i + 1))
    (( i == count )) && break
  done < "$fifo"
}

#
# Gets manager $2 version and write to fifo $1
#
async_versions.manager.version() {
  local fifo="$1"
  local manager="$2"

  local version
  version=$(core.manager.version "$manager" false)

  echo "$(async_versions.key "$manager"),$version" > "$fifo"
}

#
# Gets manager $2, package $3, version type $4 and write to fifo $1
#
async_versions.package.version() {
  local fifo="$1"
  local manager="$2"
  local package="$3"
  local type="$4"

  local version
  version=$("core.package.${type}_version" "$manager" "$package" false)

  echo "$(async_versions.key "$manager" "$package" "$type"),$version" > "$fifo"
}

#
# Populates async_versions with manager $1, package $2 local and remote version.
# Simulates cache writes.
# If fifo is supplied, writes will happen but reads MUST happen elsewhere,
# otherwise creates one.
#
async_versions.package() {
  local manager="$1"
  local package="$2"
  local fifo="$3"

  # If fifo name is not given, creates one
  local do_read=false
  if string.is_empty "$fifo"; then
    do_read=true
    fifo=$(async_versions.fifo.name "$manager" "$package")
    async_versions.fifo.new "$fifo"
  fi

  # Get local and remote versions asynchronously
  async_versions.package.version "$fifo" "$manager" "$package" "local"  &
  async_versions.package.version "$fifo" "$manager" "$package" "remote" &

  # If we have our own fifo, read it and simulate cache writes
  if $do_read; then
    async_versions.fifo.read "$fifo" 2
    async_versions.cache "$manager" "$package"
  fi
}

#
# Populates async_versions with manager $1 packages local and remote version.
# Simulates cache writes.
#
async_versions.manager() {
  local manager="$1"
  local fifo
  fifo=$(async_versions.fifo.name "$manager")

  # Creates new fifo
  async_versions.fifo.new "$fifo"

  # Get manager version asynchronously
  async_versions.manager.version "$fifo" "$manager" &

  # For all manager's packages
  local i=0
  while IFS=, read -ra line; do
    local package=${line[0]}
    # Get package versions asynchronously
    async_versions.package "$manager" "$package" "$fifo" &
    i=$((i + 1))
  done < <(core.csv.get "$manager")

  # Read fifo
  async_versions.fifo.read "$fifo" $((i * 2 + 1))

  # Simulate cache writes
  async_versions.cache "$manager"
  while IFS=, read -ra line; do
    local package=${line[0]}
    async_versions.cache "$manager" "$package"
  done < <(core.csv.get "$manager")
}

#
# Writes cache from async_versions
#
async_versions.cache() {
  local manager="$1"
  local package="$2"

  # If package is given, copy local and remote versions,
  # Else copy manager version
  if helpers.is_set "$package"; then
    local local_key
    local local_version
    local remote_key
    local remote_version
    local_key=$(async_versions.key "$manager" "$package" "local")
    remote_key=$(async_versions.key "$manager" "$package" "remote")
    local_version="${async_versions[$local_key]}"
    remote_version="${async_versions[$remote_key]}"

    cache.set "core_package_local_version__${manager}__${package}"  "$local_version" 0
    cache.set "core_package_remote_version__${manager}__${package}" "$remote_version" 0
  else
    local key
    local version
    key=$(async_versions.key "$manager")
    version="${async_versions[$key]}"

    cache.set "core_manager_version__$manager" "$version" 0
  fi
}

