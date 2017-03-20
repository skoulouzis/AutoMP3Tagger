 #!/bin/bash

 
 
urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}


IFS=$'\n'
MUSIC=/media/$USER/zapp/music/Ramones

for f in $(find $MUSIC -type f); do
    echo $f
    title=`ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 $f`
    artist=`ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 $f`
    info=$artist" "$title
    encoded=`urlencode $info`
    curl "https://en.wikipedia.org/w/api.php?action=query&format=json&redirects&list=search&srlimit=1&srsearch=$encoded"  > title.json
    title=`jq .query.search[0].title title.json`
    snipet=`jq .query.search[0].snippet title.json | tr '[:upper:]' '[:lower:]'`
    artist=`echo $artist | tr '[:upper:]' '[:lower:]'`
    if [[ $snipet == *$artist* ]]; then
        title=`sed -e 's/^"//' -e 's/"$//' <<<"$title"`
        encoded=`urlencode $title`
#         echo "https://en.wikipedia.org/w/api.php?format=json&redirects&action=query&prop=extracts&exlimit=max&explaintext&exintro&titles=$encoded"
        curl "https://en.wikipedia.org/w/api.php?format=json&redirects&action=query&prop=extracts&exlimit=max&explaintext&exintro&titles=$encoded" | jq .query.pages > pages.json
        arr=( $(jq 'keys[]' pages.json) )
        pageID=`sed -e 's/^"//' -e 's/"$//' <<<"${arr[0]}"`
        k=`jq keys[] pages.json`
        extract=`jq .$k.extract pages.json | tr '[:upper:]' '[:lower:]'`
        if [[ $extract == *"song"* ]]; then
            rm pages.json
            curl "https://en.wikipedia.org/?curid=$pageID" > $pageID.html
            genre=`w3m $pageID.html -dump -T text/html | grep  "Genre.*" | sed 's/Genre//' |  sed ':a;N;$!ba;s/\n/,/g'  | tr -d '^[1]' |  tr -d '•' | tr '[:upper:]' '[:lower:]'`
            echo $genre
            if [ -n "$genre" ]; then
                IFS=, read -r -a array <<<$genre
                echo $info ":"
                genre=""
                for i in "${array[@]}"
                do
                    genre+=`echo $i | awk '{$1=$1};1'`"/"
                done
                genre=`echo "${genre::-1}"`
                echo $genre
                mid3v2 --genre="$genre" $f
            fi
        fi
    fi
done