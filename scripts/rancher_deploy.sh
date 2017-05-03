#!/bin/bash -e

usage="$(basename "$0") [-h] [-e ENVIRONMENT] [-s STACK] [-c SERVICE] [-r RANCHER_COMMAND] [-d DOCKER_COMPOSE_FILE] [-n RANCHER_COMPOSE_FILE] [-w WAIT_TIME_SECS] -- script to upgrade and deploy containers in the given environment.
Make sure that you have rancher environment options set and rancher cli installed before running the script.

where:
-h  show this help text
-e  set the rancher environment (default: Dev)
-s  set the rancher stack (default: QA)
-c  set the rancher service (default: poseidon-app)
-r  set the rancher command (default: ./rancher)
-d  set the docker-compose file (default: deployment/docker-compose.yml)
-n  set the rancher-compose file (default: deployment/rancher-compose.yml)
-w  set the wait time in seconds (default: 120)"

env=Dev
stack=test-stack
service=test-service
rancher_command=rancher
docker_compose_file=deployment/docker-compose.yml
rancher_compose_file=deployment/rancher-compose.yml
WAIT_TIMEOUT=120
NUMBER_OF_TIMES_TO_LOOP=$(( $WAIT_TIMEOUT/10 ))

while getopts ':e:s:c:r:w:d:n:h' option; do
    case "$option" in
        h)  echo "$usage"
            exit
            ;;
        e)  env=$OPTARG
            ;;
        s)  stack=$OPTARG
            ;;
        c)  service=$OPTARG
            ;;
        r)  rancher_command=$OPTARG
            ;;
        d)  docker_compose_file=$OPTARG
            ;;
        n)  rancher_compose_file=$OPTARG
            ;;
        w)  WAIT_TIMEOUT=$OPTARG
            NUMBER_OF_TIMES_TO_LOOP=$(( $WAIT_TIMEOUT/10 ))
            ;;
        :)  printf "missing argument for -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2
            echo "$usage" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

function rename_stack() {
    projectId=`$rancher_command --env $env inspect --format '{{ .id}}' --type project $env`
    stackId=`$rancher_command --env $env inspect --format '{{ .id}}' --type stack $stack`
    echo "renaming stack $stack with id: $projectId in env $env with Id: $stackId"

    rename_status=$(curl -o /dev/null -s -w "%{http_code}\n" -u "$RANCHER_ACCESS_KEY:$RANCHER_SECRET_KEY" \
        -X PUT \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$stack-blue\"}" \
        "$RANCHER_URL/projects/${projectId}/stacks/${stackId}/")

    echo "response: $rename_status"
    if [[ $rename_status != 200 ]]
    then
        "failed to renamed service"
        exit 1
    fi
}

function upgrade_stack(){
    echo  "Upgrading $stack in $env"
    $rancher_command \
        --env $env \
        --debug \
        --wait --wait-timeout $WAIT_TIMEOUT \
        --wait-state active \
        up \
        --pull \
        --batch-size 1 \
        --stack $stack \
        --file $docker_compose_file \
        --rancher-file $rancher_compose_file \
        --force-upgrade \
        --confirm-upgrade -d
}

function check_stack_health() {
    health_status=`$rancher_command --environment $env inspect --format '{{ .healthState}}' --type stack $stack | head -n1`
    service_status=`$rancher_command --environment $env inspect --format '{{ .state}}' --type service $stack/$service | head -n1`
    echo  "Current health status of stack: $health_status"
    echo "Current state of service: $service_status"
    if [[ "$health_status" != "healthy" ]]
        then
        echo  "Stack is not in a healthy state. Exiting."
        exit 1
    fi
}

stack_exists=`$rancher_command --env $env inspect --type stack $stack | head -n1`
echo "stack exists: $stack_exists"
if [[ $stack_exists == "" ]]; then
	echo "empty result - not authorized to call Rancher API"
	exit 1
elif [[ $stack_exists != *"Not found"* ]]; then
    check_stack_health
fi
upgrade_stack
check_stack_health

