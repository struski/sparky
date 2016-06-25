#!/usr/bin/env bash

CURRENT_USERNAME=`whoami`
RUN_DIR=`pwd`

MIRROR_URL="http://ftp.ps.pl/pub/apache/spark/spark-1.6.1/"
CHECKSUM_URL="http://www.apache.org/dist/spark/spark-1.6.1/"
SPARK_INSTALL_FILENAME="spark-1.6.1-bin-hadoop2.6.tgz"
SPARK_CHECKSUM_FILENAME="spark-1.6.1-bin-hadoop2.6.tgz.md5"
SPARK_INSTALL_DIR="/opt"

#Apache Spark Config settings
SPARK_MASTER_PORT=7077
SPARK_MASTER_WEBUI_PORT=8077


# Pre-install checks
function pre_install {
    if [ ! $CURRENT_USERNAME == "root" ]; then
        cecho -r "You need to be root to run this script\n"
        exit 0
    fi

    if [ ! -f $RUN_DIR/$SPARK_INSTALL_FILENAME ]; then
        cecho -y "Could not find Apache Spark install file in current directory"
        cecho -y "File will be downloaded from $MIRROR_URL$SPARK_INSTALL_FILENAME"
        confirm_continue "Downloading Apache Spark"
        wget $MIRROR_URL$SPARK_INSTALL_FILENAME
    else
        #cecho "\nFound Apache Spark install file in current directory\n"
        cecho "\n"
    fi

    echo -e "|===============================Installing Apache Spark =============================================|"
    echo -e "|\n| Use following commands to check md5 if something goes wrong to verify the file you've downloaded:\n|"
    echo -e "| wget $CHECKSUM_URL$SPARK_CHECKSUM_FILENAME"
    echo -e "| md5sum -c $RUN_DIR/$SPARK_CHECKSUM_FILENAME\n|"
    echo -e "|====================================================================================================|"


    if [ ! -f $RUN_DIR/$SPARK_INSTALL_FILENAME ]; then
        cecho -r "\nSomething went wrong. Exiting"
        exit 1
    fi
}

function install_spark {
    local i=1
    local dirname_prefix="spark"
    local dirname=$dirname_prefix
    while [ -d "$SPARK_INSTALL_DIR/$dirname" ]
    do
        dirname="$dirname_prefix$i"
        i=i+1
    done

    cecho "\nApache Spark will be installed in $SPARK_INSTALL_DIR/$dirname\n"
    confirm_continue "Unpacking stuff ..."
    mkdir -p $SPARK_INSTALL_DIR/$dirname
    tar -xzf $SPARK_INSTALL_FILENAME -C "$SPARK_INSTALL_DIR/$dirname" --strip-components=1
    cecho -b  "Symlinking $SPARK_INSTALL_DIR/$dirname to $SPARK_INSTALL_DIR/spark-latest"
    if [ -L "$SPARK_INSTALL_DIR/spark-latest" ]; then
        rm -f "$SPARK_INSTALL_DIR/spark-latest"
    fi
    ln -s "$SPARK_INSTALL_DIR/$dirname"  "$SPARK_INSTALL_DIR/spark-latest"
    modify_environment
}

# Modify User Environment to work with Spark
function modify_environment {
    local is_env_setup=`grep "SPARK_HOME" ~/.bash_profile | wc -l`
    local bash_profile_spark_settings="
export SPARK_HOME=$SPARK_INSTALL_DIR/spark-latest
PATH=\$PATH:\$SPARK_HOME/bin
export SPARK_MASTER_PORT=$SPARK_MASTER_PORT
export SPARK_MASTER_WEBUI_PORT=$SPARK_MASTER_WEBUI_PORT
"
    if [ $is_env_setup -ge 1 ]; then
        cecho -y "Your ~/.bash_profile seems to contain some Apache Spark related configuration"
        cecho -y "Make sure it's correct. This script will not modify it"
    else
        # optionally user can choose to config his env
        cecho "User's environment will be configured now"
        confirm_continue -o "Modifying ~/.bash_profile and applying environment configuration"
        local is_confirmed=$?
        if [ $is_confirmed -eq 1 ]; then
            echo -e "$bash_profile_spark_settings" >> ~/.bash_profile
        fi
    fi

}
# Cleanup the mess
function after_install {
    cecho "\nRemoval of downloaded Apache Spark installation file"
    confirm_continue -o "Deleting $RUN_DIR/$SPARK_INSTALL_FILENAME"
    local is_confirmed=$?
    if [ $is_confirmed -eq 1 ]; then
        rm -f $RUN_DIR/$SPARK_INSTALL_FILENAME
    fi
}

function main {
    pre_install
    install_spark
    after_install
    create_start_stop_script
    display_info
    exit 1
}

#=== EVERYTHING UNDER THIS LINE IS HELPERS AND UTILITY FUNCTIONS ===
# Main is called at the end of the script

# COLORS CONST
readonly RED="\e[31m"
readonly GREEN="\e[32m"
readonly YELLOW="\e[33m"
readonly BLUE="\e[34m"
readonly RESET_COLOR="\e[0m"
readonly COLORS_DISABLED=false # if true will disable colors in messages

# Coloured echo
# @param color - default green
# @param message
function cecho {
    local color=$GREEN

    if [ $# -eq 1 ]; then
        if [ "$COLORS_DISABLED" = false  ]; then
            echo -e "$color$1$RESET_COLOR"
        else
            echo -e "$1"
        fi
            return
    fi

    case "$1" in
        -r)
            color=$RED
            ;;
        -g)
            color=$GREEN
            ;;
        -y)
            color=$YELLOW
            ;;
        -b)
            color=$BLUE
            ;;
    esac

    if [ "$COLORS_DISABLED" = false  ]; then
        echo -e "$color$2$RESET_COLOR"
    else
        echo -e "$1"
    fi
}

# Do you want to continue ?
# @param -o - optional action. This func will not exit script if NO chosen
# @param message - will be displayed if user chooses to continue with execution
# @return if used in combination with -o it returns 1- YES, 0 - NO
function confirm_continue {
    local message=""
    is_action_optional=false
    if [ $# -eq 1 ]; then
            message=$1
    elif [ $# -eq 2 ]; then
        case $1 in
            -o)
                is_action_optional=true
                message=$2
                ;;
            *)
                message=$1
        esac
    fi

    read -r -p "Do you want to continue ?  [y/N] " response
    case $response in
        [yY][eE][sS]|[yY])
            cecho -b "$message"
            if [ "$is_action_optional" = true ]; then
                return 1
            fi
            ;;
        *)
            # if action that we are confirming is optional then do not exit script if user chooses NO
            if [ "$is_action_optional" = false ]; then
                if [ -f $RUN_DIR/$SPARK_NOTEBOOK_INSTALL_FILENAME ]; then
                    cecho -r "Downloaded files will not be deleted"
                fi
                cecho -r "Bye bye"
                exit 0
            fi
            return 0
            ;;
    esac
}
#=================== SPARKY - START/STOP SCRIPT GENERATION ====================

START_STOP_SCRIPT_GENERATED=false
START_STOP_SCRIPT_NAME="sparky.sh"
IS_COPY_SCRIPT_TO_LATEST_REQUIRED=true

function create_start_stop_script {
    cecho "\nGeneration of Apache Spark start/stop script (Sparky)"
    confirm_continue -o "Generating $START_STOP_SCRIPT_NAME"
    local is_confirmed=$?
    # exit this function if user doesn't want to create the script
    if [ $is_confirmed -eq 0 ]; then
        return 0
    fi

    # start/stop script creation

    local script_path="$RUN_DIR/$START_STOP_SCRIPT_NAME"

    # if script exists comment the linest containing 'spark-latest' string
    if [ -f $script_path ]; then
        is_script_already_configured_cmd="$(grep 'spark-latest' $script_path | wc -l)"
        is_script_already_configured="${is_script_already_configured_cmd}"
        if [ $is_script_already_configured -ge 1 ]; then
            cecho -y "Script $START_STOP_SCRIPT_NAME already contains Apache Spark configuration"
            cecho -y "All lines containing string 'spark-latest' will be commented out"
            sed -i -e 's/^[^#]\+.*spark-latest.*$/#&/g' $script_path
        fi
    else
        touch $script_path
    fi


    # if shebang line does not exist then we WILL OVERWRITE THE EXISTING FILE
    local shebang_line="#!/usr/bin/env bash"
    local shebang_line_match="/usr/bin/env"
    local auto_gen_comment="# THIS FILE IS AUTO-GENERATED. Anything you put here might be eaten by Sparky!"
    local ascii_art="cat <<EOF
         \.'---.//|
         |\./|  \/
        _|.|.|_  \\\\
       /(  ) ' '  \\\\
      |  \/   . |  \\\\        Sparky: Yes Sir! WOOF! WOOF!
       \_/\__/| |
        V  /V / |
          /__/ /
          \___/\

EOF"
    is_shebang_line_present_cmd="$(grep $shebang_line_match $script_path | wc -l)"
    is_shebang_line_present="${is_shebang_line_present_cmd}"
    if [ $is_shebang_line_present -eq 0 ]; then
        echo "$shebang_line" > $script_path
        echo -e "\n" >> $script_path
        echo "$auto_gen_comment" >> $script_path
        echo -e "\n" >> $script_path
        echo "$ascii_art" >> $script_path
    fi

    # add start/stop code to the scipt

    # THEY NEED TO BE ONE-LINERS !!!!!!
    # below I am adding 2 one-liners
    local script_code="if [[ \$# -eq 1 && \"\$1\" = \"start\" ]]; then $(get_start_command)
elif [[ \$# -eq 1 && \"\$1\" = \"stop\" ]]; then $(get_stop_command) ; fi"

    echo "$script_code" >> $script_path

    if [ ! -f $script_path ]; then
        cecho -r "\nSomething went wrong with start/stop script creation"
    fi

    if [ "$IS_COPY_SCRIPT_TO_LATEST_REQUIRED" = true ]; then
        chmod +x $script_path
        mv $script_path $SPARK_INSTALL_DIR/spark-latest

        basename="$(get_file_basename $START_STOP_SCRIPT_NAME)"
        ln -s $SPARK_INSTALL_DIR/spark-latest/$START_STOP_SCRIPT_NAME $SPARK_INSTALL_DIR/spark-latest/bin/$basename
    fi

    START_STOP_SCRIPT_GENERATED=true

}

# Generates a command that will start up Apache Spark
function get_start_command {
    echo "(cd $SPARK_INSTALL_DIR/spark-latest/sbin && ./start-master.sh)"
}

# Generates a command that will stop Apache Spark
function get_stop_command {
    echo "(cd $SPARK_INSTALL_DIR/spark-latest/sbin && ./stop-master.sh)"
}

# bash string manipulation magic. just in case basename is not available
# @param path
# @return just basename of the file (without extension)
function get_file_basename {
    if [ $# -eq 1 ]; then
        p=$1
        p="${p##*/}"
        p="${p%.*}"
        echo $p
    else
        echo "sparky"
    fi
}

function display_info_start_stop_script {
    echo -e "|============================Start/Stop Script has been generated====================================|"
    if [ "$IS_COPY_SCRIPT_TO_LATEST_REQUIRED" = true ]; then
        echo -e "| "
        echo -e "| After applying changes to the enviroment variables you should be able to use following commands:"
        echo -e "| "
        echo -e "|        Start Apache Spark: $(get_file_basename $START_STOP_SCRIPT_NAME) start"
        echo -e "|        Stop Apache Spark:  $(get_file_basename $START_STOP_SCRIPT_NAME) stop"
        echo -e "| "
        echo -e "|====================================================================================================|"
    fi
}
#=============================== INFO =============================

function display_info {
    echo -e "|=========================== TODO before you can play with it =======================================|"
    echo -e "| "
    echo -e "| Run following command to apply enviroment variables or login again:"
    echo -e "| "
    echo -e "|        source ~/.bash_profile"
    echo -e "| "
    echo -e "|================================== Using Apache Spark ==============================================|"
    echo -e "|\n| Have fun with Apache Spark !\n|"
    echo -e "| "
    echo -e "| Spark is set up to run on port $SPARK_MASTER_PORT"
    echo -e "| Spark's WebUI will be available at http://localhost:$SPARK_MASTER_WEBUI_PORT"
    echo -e "| "
    echo -e "| RUN SPARK"
    echo -e "| "
    echo -e "|        Start:  $(get_start_command)"
    echo -e "|        Stop:   $(get_stop_command)"
    echo -e "| "
    echo -e "| RUN SHELLS (use 2 cores setting, will start Apache Spark if it's down)"
    echo -e "| "
    echo -e "|        Scala:    spark-shell --master local[2]"
    echo -e "|        Python:   pyspark --master local[2]"
    echo -e "|        R:        sparkR --master local[2]"
    echo -e "| "
    echo -e "| MORE INFO"
    echo -e "| "
    echo -e "|        http://spark.apache.org/docs/latest/"
    echo -e "| "
    if [ "$START_STOP_SCRIPT_GENERATED" = false ]; then
        echo -e "|====================================================================================================|"
    else
        display_info_start_stop_script
    fi


}

#=================== START THIS SCRIPT GODDAMMIT !  ============================
main

