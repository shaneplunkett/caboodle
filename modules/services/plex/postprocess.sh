recording=$1
encoded="$recording.hevc"
trap 'rm -f "$encoded"' EXIT
unset LD_LIBRARY_PATH

probe() {
  ffprobe -v error -analyzeduration 60M -probesize 200M -select_streams v:0 -show_entries "$1" -of csv=p=0 "$2" |
    awk 'NF && !seen++'
}

keep() {
  logger -t plex-dvr-hevc "kept the original of $recording: $1"
  exit 0
}

[ "$(probe stream=codec_name "$recording")" = hevc ] && keep "already HEVC"

filters=()
case "$(probe stream=field_order "$recording")" in
  tt | bb | tb | bt) filters=(-vf deinterlace_vaapi=rate=field) ;;
esac

ffmpeg -hide_banner -nostdin -loglevel error -y \
  -analyzeduration 60M -probesize 200M \
  -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
  -i "$recording" \
  -map 0:v:0 -map 0:a "${filters[@]}" \
  -c:v hevc_vaapi -profile:v main -rc_mode CQP -qp 25 \
  -c:a copy \
  -f matroska "$encoded" || keep "ffmpeg failed"

before=$(probe format=duration "$recording")
after=$(probe format=duration "$encoded")
awk -v a="$before" -v b="$after" 'BEGIN { exit !(a - b < 2 && b - a < 2) }' ||
  keep "durations differ: $before vs $after"

mv "$encoded" "$recording"
logger -t plex-dvr-hevc "encoded $recording to HEVC"
