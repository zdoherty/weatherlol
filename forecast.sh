#!/bin/bash
#
# what: prints out the upcoming weather forecast
#
# load variables
set -e
. config.sh

# FORECACHE="weather.json"
FORECACHE="$(mktemp)"
curl -o $FORECACHE $APIHOST

wq () {
    local FILTER
    FILTER=$1
    RET="$(jq -r $FILTER $FORECACHE)"
    if [[ $? != 0 ]]; then
        echo "forecast is invalid JSON ($FORECACHE)"
        exit 1
    fi
    echo $RET
}

t1 () {
    printf "\t${@}\n"
}

unix_to_hourmin () {
    local TIMESTAMP
    read TIMESTAMP
    date -d @$TIMESTAMP +%H:%M
}

unix_to_date () {
    local TIMESTAMP
    read TIMESTAMP
    date -d @$TIMESTAMP +%m/%d
}

tab () {
    printf "%6s %s\n" $1 $2
}

percent () {
    local FLOAT
    read FLOAT
    printf "%.0f%%\n" $(echo $FLOAT \* 100 | bc)
}

summarize_day () {
    local ROOT
    ROOT=$1
    echo "==== $(wq $ROOT.time | unix_to_date) ===="
    tab temp: "$(wq $ROOT.apparentTemperatureLow)° - $(wq $ROOT.apparentTemperatureHigh)°"
    tab sun: "$(wq $ROOT.sunriseTime | unix_to_hourmin) - $(wq $ROOT.sunsetTime | unix_to_hourmin)"
    tab moon: "$(wq $ROOT.moonPhase | percent)"
    tab rain: "$(wq $ROOT.precipProbability | percent)"
}

summarize_hour () {
    local ROOT
    ROOT=$1
    echo "==== $(wq $ROOT.time | unix_to_hourmin) ===="
    tab temp: $(wq $ROOT.temperature)°
    tab uv: $(wq $ROOT.uvIndex)
    tab rain: $(wq $ROOT.precipProbability | percent)
    tab cloud: $(wq $ROOT.cloudCover | percent)
}

cat <<'EOF'
    ____        _ __         ______                                __
   / __ \____ _(_) /_  __   / ____/___  ________  _________ ______/ /_
  / / / / __ `/ / / / / /  / /_  / __ \/ ___/ _ \/ ___/ __ `/ ___/ __/
 / /_/ / /_/ / / / /_/ /  / __/ / /_/ / /  /  __/ /__/ /_/ (__  ) /_
/_____/\__,_/_/_/\__, /  /_/    \____/_/   \___/\___/\__,_/____/\__/
                /____/
EOF

paste \
    <(summarize_day ".daily.data[0]") \
    <(summarize_day ".daily.data[1]") \
    <(summarize_day ".daily.data[2]") \
    <(summarize_day ".daily.data[3]") 

cat <<'EOF'

    __  __                 __         ______                                __
   / / / /___  __  _______/ /_  __   / ____/___  ________  _________ ______/ /_
  / /_/ / __ \/ / / / ___/ / / / /  / /_  / __ \/ ___/ _ \/ ___/ __ `/ ___/ __/
 / __  / /_/ / /_/ / /  / / /_/ /  / __/ / /_/ / /  /  __/ /__/ /_/ (__  ) /_
/_/ /_/\____/\__,_/_/  /_/\__, /  /_/    \____/_/   \___/\___/\__,_/____/\__/
                         /____/
EOF

for I in {0..11..4}; do
    paste \
        <(summarize_hour ".hourly.data[$I]") \
        <(summarize_hour ".hourly.data[$(($I + 1))]") \
        <(summarize_hour ".hourly.data[$(($I + 2))]") \
        <(summarize_hour ".hourly.data[$(($I + 3))]")
done
