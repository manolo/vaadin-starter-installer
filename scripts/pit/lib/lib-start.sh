. `dirname $0`/lib/lib-validate.sh

## Generate an app from start.vaadin.com with the given preset, and unzip it in the current folder
## multiple presets can be used by joining them with the `_` character
downloadStarter() {
  _preset=$1
  _presets=""
  for _p in `echo "$_preset" | tr "_" " "`
  do
    _presets="$_presets&preset=$_p"
  done
  _url="https://start.vaadin.com/dl?${_presets}&projectName=${_preset}"
  _zip="$_preset.zip"

  log "Downloading $_url"
  curl -s -f "$_url" -o $_zip \
    && unzip -q $_zip \
    && rm -f $_zip || return 1

  _new=`echo "$_preset" | tr "_" "-"`
  [ "$_new" != "$_preset" ] && mv "$_new" "$_preset" || return 0
}

## get the selenium IDE test file used for each starter
getStartTestFile() {
  case $1 in
   latest-java|latest-java-top|latest-javahtml|latest-typescript|latest-typescript-top)
     echo "latest-java.side";;
   latest-java_partial-auth|latest-java-top_partial-auth)
     echo "latest-java-auth.side";;
   latest-typescript_partial-auth)
     echo "latest-typescript-auth.side";;
   *)
     echo "$1.side";;
  esac
}

## Run an App downloaded from start.vaadin.com by following the next steps
# 1. generate the project and download from start.vaadin.com (if not in offline)
# 2. run validations in the current version to check that it's not broken
# 3. increase version to the version used for PiT (if version given)
# 4. run validations for the new version in dev-mode
# 5. run validations for the new version in prod-mode (if project can be run in prod and dev)
runStarter() {
  _preset="$1"
  _tmp="$2"
  _port="$3"
  _version="$4"
  _offline="$5"

  ## For typescript starters, use hilla.version property and the equivalent version numering
  _versionProp=vaadin.version
  if echo "$_preset" | grep -q typescript
  then
    _version=`echo $_version | sed -e 's,^23,1,'`
    _versionProp=hilla.version
  fi
  _test=`getStartTestFile $_preset`

  echo ""
  log "================= TESTING start preset '$_preset' $_offline =================="

  cd "$_tmp"
  _dir="$_tmp/$_preset"
  if [ -z "$_offline" ]
  then
    [ -d "$_dir" ] && log "Removing project folder $_dir" && rm -rf $_dir
    # 1
    downloadStarter $_preset || return 1
  fi
  cd "$_dir" || return 1
  
  # 2
  runValidations current $_preset $_port "mvn -B clean" "mvn -B" "Frontend compiled" "$_test" || return 1
  # 3
  if setVersion $_versionProp $_version
  then
    # 4
    runValidations $_version $_preset $_port "mvn -B clean" "mvn -B" "Frontend compiled" "$_test" || return 1
    # 5
    runValidations $_version $_preset $_port 'mvn -B -Pproduction package' 'java -jar target/*.jar' "Generated demo data" "$_test" || return 1
  fi
  log "==== start preset '$_preset' was build and tested successfuly ===="
}
