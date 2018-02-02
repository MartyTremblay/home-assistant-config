#!/bin/bash

#NOTE: Edit "user", "pass", ip and port below
JSONRPC="http://192.168.101.13:9000/jsonrpc.js"

#Example command arguments
#mac="00:04:20:01:02:03"
#alert_song="//volume1//homeassistant//beep.mp3"
#alert_volume=60

mac=$1
alert_song=$2
alert_volume=$3

#get power state
power=$(curl -X GET -H "Content-Type: application/json" \
                  -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["power","?"]]}' \
                  $JSONRPC | jq '.result._power')

prev_power=0
if [[ $power =~ .*1.* ]] ; then
  prev_power=1
fi
echo "prev_power=$prev_power"

#get play mode
prev_mode=$(curl -X GET -H "Content-Type: application/json" \
                 -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["mode","?"]]}' \
                 $JSONRPC | jq '.result._mode')
echo "prev_mode=$prev_mode"

if [[ $prev_mode =~ .*play.* ]] ; then
  # pause any currently playing song
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["pause"]]}' $JSONRPC
  echo "pause"

  #May want to pause here before playing alert song
  #sleep 1
fi

# GET SETTINGS TO RESTORE AFTER PLAYING ALERT SONG
#get current volume
prev_volume=$(curl -X GET -H "Content-Type: application/json" \
                   -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["mixer","volume","?"]]}' \
                   $JSONRPC | jq '.result._volume')
echo "prev_volume=$prev_volume"

#get current repeat setting
prev_repeat=$(curl -X GET -H "Content-Type: application/json" \
                   -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","repeat","?"]]}' \
                   $JSONRPC | jq '.result._repeat')
echo "prev_repeat=$prev_repeat"

# SET SETTINGS FOR ALERT SONG
#set alert_volume to command argument value
curl -X GET -H "Content-Type: application/json" \
     -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["mixer","volume",'$alert_volume']]}' $JSONRPC
echo "set alert_volume"

#set repeat setting to 0
curl -X GET -H "Content-Type: application/json" \
     -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","repeat",0]]}' $JSONRPC
echo "set repeat_setting to 0"

#get number of tracks
num_tracks=$(curl -X GET -H "Content-Type: application/json" \
                  -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","tracks","?"]]}' \
                  $JSONRPC | jq '.result._tracks')
echo "num_tracks=$num_tracks"

prev_time=0
prev_index=0

# IF MUSIC IS PLAYING, SAVE OFF INFO TO RESUME LATER
if [[ $prev_mode =~ .*play.* ]] ; then
  echo "music is playing"

  # get paused time
  prev_time=$(curl -X GET -H "Content-Type: application/json" \
                   -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["time","?"]]}' \
                   $JSONRPC | jq '.result._time')
  echo "prev_time=$prev_time"

  #get current song index
  prev_index=$(curl -X GET -H "Content-Type: application/json" \
                   -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","index","?"]]}' \
                   $JSONRPC | jq '.result._index')
  echo "prev_index=$prev_index"

  #add alert song to end
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","add","'"$alert_song"'"]]}' $JSONRPC
  echo "add alert song to end"

  #jump to and play alert song
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","index",'"$num_tracks"']]}' $JSONRPC
  echo "jump to and play alert song"

else
  #play alert song (this will clear current playlist)
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","play","'"$alert_song"'"]]}' $JSONRPC
  echo "play alert song"
fi

# WAIT FOR ALERT SONG TO STOP PLAYING
echo "wait for alert song to stop playing"
cur_mode="play"
while [[ $cur_mode =~ .*play.* ]]; do
  sleep 1
  cur_mode=$(curl -X GET -H "Content-Type: application/json" \
              -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["mode","?"]]}' \
              $JSONRPC | jq '.result._mode')
done

echo "alert song stopped playing"

# RESTORE PREVIOUS SETTINGS
#restore prev_volume setting
curl -X GET -H "Content-Type: application/json" \
     -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["mixer","volume",'"$prev_volume"']]}' $JSONRPC
echo "restore prev_volume setting"

#restore prev_repeat setting
curl -X GET -H "Content-Type: application/json" \
     -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","repeat",'"$prev_repeat"']]}' $JSONRPC
echo "restore prev_repeat setting"

#restore prev_power setting
if [ $prev_power -eq 0 ] ; then
  echo "prev_power setting was off, power off"
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["power",0]]}' $JSONRPC

# RESUME PREVIOUSLY PLAYING MUSIC
elif [[ $prev_mode =~ .*play.* ]] ; then
  # delete alert song from playlist
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","delete",'"$num_tracks"']]}' $JSONRPC
  echo "delete alert song from playlist"

  #jump to and play prev_index
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["playlist","index",'"$prev_index"',1]]}' $JSONRPC
  echo "jump to and play prev_index"

  #skip ahead in song to prev_time
  curl -X GET -H "Content-Type: application/json" \
       -d '{"id":1,"method":"slim.request","params":["'"$mac"'",["time",'"$prev_time"']]}' $JSONRPC
  echo "skip ahead in song to prev_time"
fi
