#!/bin/bash -e

SHORT_SLEEP=1
LONG_SLEEP=10
FAILURE_COUNT=0
SUCCESS_COUNT=0
MIN_SUCCESS_COUNT=10
MAX_FAILURE_COUNT=90

while [ $SUCCESS_COUNT -lt $MIN_SUCCESS_COUNT ]; do

  if [ $FAILURE_COUNT -gt $MAX_FAILURE_COUNT ]; then
    echo "Error: Application healthcheck timeout: ${HEALTHCHECKURL}"
    exit 1;
  fi

  STATUS=$(curl -i -s ${HEALTHCHECKURL} --max-time 5 | head -1 | grep -Eo "\d{3}")

  if [ $STATUS = "200" ]; then
    echo "Successful response from: ${HEALTHCHECKURL}"
    SUCCESS_COUNT=$[$SUCCESS_COUNT + 1]
    echo "Consecutive Successful responses so far: ${SUCCESS_COUNT}"
    sleep $SHORT_SLEEP
  else
    echo "Error: Application healthcheck did not respond with HTTP 200: ${HEALTHCHECKURL} [$STATUS], resetting success count to 0"
    SUCCESS_COUNT=0
    FAILURE_COUNT=$[$FAILURE_COUNT + 1]
    echo "Number of failed curl attempts so far: ${FAILURE_COUNT}"
    echo "Waiting on Application for ${LONG_SLEEP} secs before attempting the next curl ..."
    sleep $LONG_SLEEP
  fi

done

echo "Application started"
