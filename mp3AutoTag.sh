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


search(){
    encoded=$1
#     echo "https://en.wikipedia.org/w/api.php?action=query&format=json&redirects&list=search&srlimit=1&srsearch=$encoded"
    curl "https://en.wikipedia.org/w/api.php?action=query&format=json&redirects&list=search&srlimit=1&srsearch=$encoded"  > title.json
    title=`jq .query.search[0].title title.json`
    snipet=`jq .query.search[0].snippet title.json | sed -e 's/<\/b>/-/g' -e 's/<[^>]*>//g'  | tr '[:upper:]' '[:lower:]'`
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
            curl "https://en.wikipedia.org/?curid=$pageID" | hxnormalize -x > $pageID.html
            xpath -e '//tr[position()>1]' $pageID.html 2> /dev/null | sed -e 's/<\/*tr>//g' -e 's/<td>//g' -e 's/<\/td>/ /g' | awk 'NF' > $pageID.out
            rm $pageID.html
            if grep -q "Music genre" "$pageID.out"; then
            genre=""
                while read p; do
                    if [[ $p == *"<th scope=\""* ]] && [ "$startLooking" = true ]; then
                        startLooking=false
                        break
                    fi
                    if [[ $p == *"title=\"Music genre\""* ]]; then
                        genre=""
                        startLooking=true
                    fi
                    if [[ $p == *"title=\""* ]] && [ "$startLooking" = true ] && [[ $p != *"Music genre"* ]]; then
                        split=`echo $p | grep -o -P '(?<=title\=\")(.*?)(?=\")' | tr '\n' '\/'`
                        split=`urldecode $split`
                        split=`echo $split | sed 's/\&amp;/\&/g'`
                        genre+=$split
                    fi
                done < $pageID.out
            fi
        fi
    fi
}


IFS=$'\n'
MUSIC=/media/$USER/zapp/music/Orbital


for f in $(find $MUSIC -type f -iname "*.mp3"); do
#     echo $f
    title=`ffprobe -loglevel error -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 $f`
    artist=`ffprobe -loglevel error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 $f`
    info=$artist" "$title
#     echo $info
    encoded=`urlencode $info`

    genre=""
    search $encoded 
    if [ -n "$genre" ]; then
        genre=`echo "${genre::-1}"`
        echo $artist $title
        echo $f
        echo $genre
        mid3v2 --genre="$genre" $f
    fi
    genre=""
    rm *.html
done
rm *.json
rm *.out
