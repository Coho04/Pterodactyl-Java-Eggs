# Source of the "startup" command in egg-java-build-runner.json.
# Write it into the egg with:  sh scripts/build-egg-startup.sh
#
# Rules: refer to egg variables as shell variables ($ACCESS_TOKEN), never with the panel
# placeholder syntax - the panel would substitute the real value before the entrypoint prints
# the command. Never write two opening curly braces in a row (the entrypoint turns them into "${").
#
# Repository access (GIT_AUTH):
#   auto        token if ACCESS_TOKEN is set, else deploy key if one exists, else anonymous
#   token       HTTPS with USERNAME/ACCESS_TOKEN, sent as a header - never stored on disk
#   deploy_key  SSH with /home/container/.ssh/deploy_key; generated on first start, the public
#               key is printed so it can be added as a read-only deploy key
#   none        anonymous HTTPS (public repositories)
#
# The checkout in /home/container/repo is kept between starts. If fetching or building fails,
# the last successfully built JAR is started instead.
cd /home/container || exit 1;
mkdir -p logs;
REPO_DIR=/home/container/repo;
KEY=/home/container/.ssh/deploy_key;
BR="${BRANCH:-main}";
MODE="${GIT_AUTH:-auto}";
if [[ "$GITHUB_REPO_URL" =~ ^git@([^:]+):(.+)$ ]]; then
    GHOST="${BASH_REMATCH[1]}"; GPATH="${BASH_REMATCH[2]}";
elif [[ "$GITHUB_REPO_URL" =~ ^https?://([^@/]+@)?([^/]+)/(.+)$ ]]; then
    GHOST="${BASH_REMATCH[2]}"; GPATH="${BASH_REMATCH[3]}";
else
    echo -e "[ERROR] GITHUB_REPO_URL must look like https://host/owner/repo or git@host:owner/repo"; exit 1;
fi;
GPATH="${GPATH%/}"; GPATH="${GPATH%.git}";
if [ "$MODE" = "auto" ]; then
    if [ -n "$ACCESS_TOKEN" ]; then MODE=token; elif [ -f "$KEY" ]; then MODE=deploy_key; else MODE=none; fi;
fi;
case "$MODE" in token|deploy_key|none) ;; *) echo -e "[ERROR] GIT_AUTH must be auto, token, deploy_key or none"; exit 1;; esac;
if [ "$MODE" = "deploy_key" ]; then
    REMOTE="git@$GHOST:$GPATH.git";
    mkdir -p /home/container/.ssh && chmod 700 /home/container/.ssh;
    if [ ! -f "$KEY" ]; then
        ssh-keygen -q -t ed25519 -N "" -C "pelican-${P_SERVER_UUID:-$HOSTNAME}" -f "$KEY" || { echo -e "[ERROR] ssh-keygen failed"; exit 1; };
        echo -e "[SETUP] New deploy key generated. Add this public key as a READ-ONLY deploy key to $GHOST/$GPATH, then restart:";
        cat "$KEY.pub";
    fi;
    if [ "$GHOST" = "github.com" ]; then
        echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" > /home/container/.ssh/known_hosts; HKC=yes;
    else
        HKC=accept-new;
    fi;
    export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o UserKnownHostsFile=/home/container/.ssh/known_hosts -o StrictHostKeyChecking=$HKC";
else
    REMOTE="https://$GHOST/$GPATH.git";
fi;
if [ "$MODE" = "token" ]; then
    GIT_B64=$(printf '%s:%s' "${USERNAME:-x-access-token}" "$ACCESS_TOKEN" | base64 | tr -d '\n');
fi;
g() { if [ "$MODE" = "token" ]; then git -c "http.extraHeader=Authorization: Basic $GIT_B64" "$@"; else git "$@"; fi; };
UPDATED=0;
if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" remote set-url origin "$REMOTE";
    if [ "${AUTO_UPDATE:-true}" = "true" ]; then
        echo -e "[SETUP] Updating the repository ($MODE)";
        if g -C "$REPO_DIR" fetch --prune --tags origin && git -C "$REPO_DIR" reset --hard "${DEPLOY_REF:-origin/$BR}"; then UPDATED=1; else echo -e "[WARN] git fetch failed - keeping the code already present"; fi;
    else
        echo -e "[SETUP] AUTO_UPDATE=false - keeping the code already present ($(git -C "$REPO_DIR" rev-parse --short HEAD))";
    fi;
else
    rm -rf "$REPO_DIR";
    echo -e "[SETUP] Cloning the repository ($MODE)";
    if g clone -b "$BR" "$REMOTE" "$REPO_DIR"; then
        UPDATED=1;
        if [ -n "$DEPLOY_REF" ]; then git -C "$REPO_DIR" reset --hard "$DEPLOY_REF"; fi;
    else
        rm -rf "$REPO_DIR"; echo -e "[WARN] Clone failed - check GITHUB_REPO_URL, BRANCH and the access method ($MODE)";
    fi;
fi;
unset ACCESS_TOKEN GIT_B64;
if [ -f "$REPO_DIR/pom.xml" ] && { [ "$UPDATED" = "1" ] || [ ! -f "/home/container/$RUN_FILE" ]; }; then
    echo -e "[SETUP] Building with Maven";
    if (cd "$REPO_DIR" && mvn clean package -Dfile.encoding=UTF-8) && cp "$REPO_DIR/target/$RUN_FILE" "/home/container/$RUN_FILE"; then
        echo -e "[SETUP] Copied $RUN_FILE to /home/container/";
    else
        echo -e "[WARN] Maven build failed - starting the last built $RUN_FILE if present";
    fi;
fi;
if [ ! -f "/home/container/$RUN_FILE" ]; then
    echo -e "[ERROR] /home/container/$RUN_FILE not found and no build possible"; exit 1;
fi;
cd /home/container;
java -Dterminal.jline=false -Dterminal.ansi=true -jar "/home/container/$RUN_FILE" 2>&1 | tee logs/latest.log
