# Kivun Terminal — shared language → prompt map.
# Sourced by the Linux launcher and the macOS desktop .command shortcut
# so both stay in sync with the documented 23-language set. The Windows
# .bat cannot source this; if you add a language here you must also
# update `:SET_LANG_PROMPT` in payload/kivun-terminal.bat.
#
# Both the hyphen form (e.g. `azeri-south`) and the underscore form
# (e.g. `azeri_south`) are accepted — the hyphen form is canonical and
# documented in every README; underscore is backwards-compat for users
# migrating from older configs.

kivun_lang_prompt() {
    # Writes the --append-system-prompt text (or nothing) to stdout for
    # the language key in $1. Usage:
    #   LANG_PROMPT=$(kivun_lang_prompt "$RESPONSE_LANGUAGE")
    case "$1" in
        hebrew)                  echo "Always respond in Hebrew. When mixing Hebrew with English words, code identifiers, paths, or numbers, always insert a space between the Hebrew text and the foreign token (write 'הקובץ src/index.ts' not 'הקובץsrc/index.ts'). Place demonstratives like הזה / הזאת / האלה AFTER the foreign noun with a space (write 'ה-endpoint הזה' not 'הזה-endpoint'). The 'ה-' prefix attaches to a single foreign noun directly via hyphen with no space (e.g. 'ה-API', 'ה-backend'); other Hebrew words must be space-separated from foreign tokens." ;;
        arabic)                  echo "Always respond in Arabic." ;;
        persian)                 echo "Always respond in Persian (Farsi)." ;;
        urdu)                    echo "Always respond in Urdu." ;;
        kurdish)                 echo "Always respond in Kurdish." ;;
        pashto)                  echo "Always respond in Pashto." ;;
        sindhi)                  echo "Always respond in Sindhi." ;;
        yiddish)                 echo "Always respond in Yiddish." ;;
        syriac)                  echo "Always respond in Syriac." ;;
        dhivehi)                 echo "Always respond in Dhivehi (Maldivian)." ;;
        nko)                     echo "Always respond in N'Ko." ;;
        adlam)                   echo "Always respond in Fulani using the Adlam script." ;;
        mandaic)                 echo "Always respond in Mandaic." ;;
        samaritan)               echo "Always respond in Samaritan Hebrew." ;;
        dari)                    echo "Always respond in Dari." ;;
        uyghur)                  echo "Always respond in Uyghur." ;;
        balochi)                 echo "Always respond in Balochi." ;;
        kashmiri)                echo "Always respond in Kashmiri." ;;
        shahmukhi)               echo "Always respond in Punjabi using the Shahmukhi script." ;;
        azeri-south|azeri_south) echo "Always respond in Southern Azerbaijani." ;;
        jawi)                    echo "Always respond in Malay using the Jawi script." ;;
        turoyo)                  echo "Always respond in Turoyo (Neo-Aramaic)." ;;
        english|"")              ;;  # default: no prompt appended
        *)                       ;;  # unknown key: silently no prompt
    esac
}
