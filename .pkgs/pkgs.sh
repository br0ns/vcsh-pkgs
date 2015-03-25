#!/bin/bash

P_DIR=$(dirname "$0")

function promptyn () {
    if [ $# -eq 2 ] ; then
        if [ $2 -eq 1 ] ; then
            p="[Y/n]"
        else
            p="[y/N]"
        fi
    else
        p="[y/n]"
    fi
    while true; do
        read -p "$1 $p " yn
        if [ "x$yn" == "xy" ] || \
               [ "x$yn" == "xyes" ] || \
               [ "x$yn" == "xY" ] || \
               [ "x$yn" == "xYes" ] || \
               [ "x$yn" == "xYES" ] || \
               [[ "x$yn" == "x" && $# -eq 2 && $2 -eq 1 ]] ; then
            echo "y"
            return
        fi
        if [ "x$yn" == "xn" ] || \
               [ "x$yn" == "xno" ] || \
               [ "x$yn" == "xN" ] || \
               [ "x$yn" == "xNo" ] || \
               [ "x$yn" == "xNO" ] || \
               [[ "x$yn" == "x" && $# -eq 2 && $2 -eq 0 ]] ; then
            echo "n"
            return
        fi
        echo "Please answer yes or no" > /dev/stderr
    done
}

function promptoptions () {
    while true ; do
        read -p "$1 " opt
        if [ "x${opt}" == "x" ] ; then
            echo "$3"
            return
        fi
        if [[ "$2" =~ (^| )${opt}($| ) ]] ; then
            echo "${opt}"
            return
        fi
        echo "Invalid option" > /dev/stderr
    done
}

function strstr () {
    x="${1%%$2*}"
    [[ "$x" = "$1" ]] && echo -1 || echo ${#x}
}


function promptlist () {
    PROMPT="[$(echo "$1" | sed "s/\($2\)/\U\1/" | sed "s/./\0\\//g" | \
               head -c -2)] "
    while true ; do
        read -p "$PROMPT" opt
        if [ ${#opt} -eq 0 ] ; then
            opt=$2
        fi
        if [ ${#opt} -eq 1 ] ; then
            # downcase
            opt=${opt,,}
            if [[ $1 == *"$opt"* ]] ; then
                echo $opt
                return
            fi
        fi
        echo "?" > /dev/stderr
    done
}

function plural () {
    echo -n "$1"
    if [ $2 -ne 1 ] ; then
        echo -n s
    fi
}

function check-pkgs () {
    P_WANTED=$P_DIR/wanted.pkgs
    N_WANTED=0

    P_IGNORE=$P_DIR/ignore.pkgs
    N_IGNORE=0

    P_REMIND=$P_DIR/remind.pkgs
    N_REMIND=0

    P_DELETE=$P_DIR/delete.pkgs
    N_DELETE=0

    if [ ! -f "$P_WANTED" ] ; then
        touch "$P_WANTED"
    fi

    if [ ! -f "$P_IGNORE" ] ; then
        touch "$P_IGNORE"
    fi

    if [ ! -f "$P_REMIND" ] ; then
        touch "$P_REMIND"
    fi

    if [ ! -f "$P_DELETE" ] ; then
        touch "$P_DELETE"
    fi

    for pkg in $(deborphan --no-show-section -an) ; do
        grep -q "^$pkg$" "$P_WANTED" && continue
        grep -q "^$pkg$" "$P_IGNORE" && continue
        grep -q "^$pkg$" "$P_REMIND" && continue

        echo "Orphaned package: $pkg"

        if grep -q "^${pkg}$" "$P_DELETE" ; then
            case $(promptyn "Package was marked for deletion.  Delete?" 1) in
                y)
                    N_DELETE=$(($N_DELETE + 1))
                    sudo apt-get purge "$pkg"
                    continue
                    ;;
                n)
                    echo "Removed package from delete.pkgs"
                    grep -v "^$pkg$" "$P_DELETE" | sponge "$P_DELETE"
                    ;;
            esac
        fi

        echo "  [w] I want this package"
        echo "  [i] Ignore package in the future"
        echo "  [r] Remind me later"
        echo "  [d] Delete package"
        opt=$(promptlist "wird" "r")

        case $opt in
            w)
                N_WANTED=$(($N_WANTED + 1))
                echo "$pkg" >> $P_WANTED
                ;;
            i)
                N_IGNORE=$(($N_IGNORE + 1))
                echo "$pkg" >> $P_IGNORE
                ;;
            r)
                N_REMIND=$(($N_REMIND + 1))
                echo "$pkg" >> $P_REMIND
                ;;
            d)
                N_DELETE=$(($N_DELETE + 1))
                sudo apt-get purge "$pkg"
                ;;
        esac

    done

    if [ $N_WANTED -gt 0 ] ; then
        echo "Added $N_WANTED $(plural package $N_WANTED) to wanted.pkgs"
        sort "$P_WANTED" --output "$P_WANTED"
    fi

    if [ $N_IGNORE -gt 0 ] ; then
        echo "Added $N_IGNORE $(plural package $N_IGNORE) to ignore.pkgs"
        sort "$P_IGNORE" --output "$P_IGNORE"
    fi

    if [ $N_REMIND -gt 0 ] ; then
        echo "Added $N_REMIND $(plural package $N_REMIND) to remind.pkgs"
        sort "$P_REMIND" --output "$P_REMIND"
    fi

    if [ $N_DELETE -gt 0 ] ; then
        echo "Added $N_DELETE $(plural package $N_DELETE) to delete.pkgs"
        sort "$P_DELETE" --output "$P_DELETE"
    fi

}

function remind-pkgs () {
    P_REMIND=$P_DIR/remind.pkgs

    rm -f $P_REMIND
    echo "Re-checking packages"
    check-pkgs
}
