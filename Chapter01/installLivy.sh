#!/bin/bash

# Shell script for installing Spark from binaries 
#
# PySpark Cookbook
# Author: Tomasz Drabas, Denny Lee
# Version: 0.1
# Date: 12/2/2017

_livy_binary="http://mirrors.ocf.berkeley.edu/apache/incubator/livy/0.4.0-incubating/livy-0.4.0-incubating-bin.zip"
_livy_archive=$( echo "$_livy_binary" | awk -F '/' '{print $NF}' )
_livy_dir=$( echo "${_livy_archive%.*}" )
_livy_destination="/opt/livy"
_hadoop_destination="/opt/hadoop"

# parse command line arguments
_args_len="$#"

if [ "$_args_len" -ge 0 ]; then

    while [[ "$#" -gt 0 ]]
    do
        key="$1"

        case $key in
            -ns|--nosudo)
            _spark_destination="~/livy"
            _hadoop_destination="~/hadoop"
            shift
            ;;
            *)
            break ;;
        esac
    done
fi

function checkOS(){
    _uname_out="$(uname -s)"

    # echo "$_uname_out"
    case "$_uname_out" in
        Linux*)     _machine="Linux";;
        Darwin*)    _machine="Mac";;
        *)          _machine="UNKNOWN:${_uname_out}"
    esac

    if [ "$_machine" = "UNKNOWN:${_uname_out}" ]; then
        echo "Machine $_machine. Stopping."
        exit
    fi
}

function printHeader() {
    echo
    echo "####################################################"
    echo
    echo "Installing Livy from binaries on $_machine"
    echo
    echo "The binaries will be moved to $_livy_destination"
    echo
    echo "PySpark Cookbook by Tomasz Drabas and Denny Lee"
    echo "Version: 0.1, 12/8/2017"
    echo
    echo "####################################################"
    echo
    echo
}

function createTempDir() {
    if [ -d _temp ]; then
        rm -rf _temp
    fi

    mkdir _temp
    cd _temp
}

# Download the package
downloadThePackage() {
    echo
    echo "##########################"
    echo
    echo "Downloading the $1"
    echo

    if [ "$_machine" = "Mac" ]; then
        curl -O "$1"
    elif [ "$_machine" = "Linux" ]; then
        wget "$1"
    else
        echo "System: $_machine not supported."
        exit
    fi

    echo
}

# Unpack the archive
function unpack() {
    echo
    echo "##########################"
    echo
    echo "Unpacking the $1"
    echo
    tar -xf "$1"

    echo
}

# Move the binaries
function moveTheBinaries() {
    echo
    echo "##########################"
    echo
    echo "Moving the binaries to $2"
    echo

    if [ -d "$2" ]; then
        sudo rm -rf "$2"
    fi

    sudo mv "$1/" "$2/"

    echo
}

function checkHadoop() {
    echo
    echo "##########################"
    echo
    echo "Checking Hadoop installation"
    echo

    if type -p hadoop; then
        echo "Hadoop executable found in PATH"
        _hadoop=hadoop
    elif [[ -n "$HADOOP_HOME" ]] && [[ -x "$HADOOP_HOME/bin/hadoop" ]];  then
        echo "Found Hadoop executable in HADOOP_HOME"
        _hadoop="$HADOOP_HOME/bin/hadoop"
    else
        echo "No Hadoop found. You should install Hadoop first. You can still continue but some functionality might not be available. "
        echo 
        echo -n "Do you want to install the latest version of Hadoop? [y/n]: "
        read _install_hadoop

        case "$_install_hadoop" in
            y*)    installHadoop ;;
            n*)    echo "Will not install Hadoop" ;;
            *)     echo "Will not install Hadoop" ;;
        esac
    fi
}

function installHadoop() {
    _hadoop_binary="http://mirrors.ocf.berkeley.edu/apache/hadoop/common/hadoop-2.9.0/hadoop-2.9.0.tar.gz"
    _hadoop_archive=$( echo "$_hadoop_binary" | awk -F '/' '{print $NF}' )
    _hadoop_dir=$( echo "${_hadoop_archive%.*}" )
    _hadoop_dir=$( echo "${_hadoop_dir%.*}" )

    downloadThePackage $( echo "${_hadoop_binary}" )
    unpack $( echo "${_hadoop_archive}" )
    moveTheBinaries $( echo "${_hadoop_dir}" ) $( echo "${_hadoop_destination}" )
}

function installJupyterKernels() {
    echo
    echo "##########################"
    echo
    echo "Installing Jupyter kernels"
    echo 
    echo "This portion of the script"
    echo "will install sparkmagic and"
    echo "additional kernels to be"
    echo "available in Jupyter."

    # install the library 
    pip install sparkmagic
    echo

    # ipywidgets should work properly
    jupyter nbextension enable --py --sys-prefix widgetsnbextension 
    echo

    # install kernels
    _sparkmagic_location=$(pip show sparkmagic | awk -F ':' '/Location/ {print $2}') # get the location of sparkmagic

    _temp_dir=$(pwd) # store current working directory

    cd $_sparkmagic_location # move to the sparkmagic folder
    jupyter-kernelspec install sparkmagic/kernels/sparkkernel
    jupyter-kernelspec install sparkmagic/kernels/pysparkkernel
    jupyter-kernelspec install sparkmagic/kernels/pyspark3kernel

    echo

    # enable the ability to change clusters programmatically
    jupyter serverextension enable --py sparkmagic
    echo

    # install autowizwidget
    pip install autovizwidget

    cd $_temp_dir
}

function setSparkEnvironmentVariables() {
    echo
    echo "##########################"
    echo
    echo "Setting Spark Environment variables"
    echo

    if [ "$_machine" = "Mac" ]; then
        _bash=~/.bash_profile
    else
        _bash=~/.bashrc
    fi
    _today=$( date +%Y-%m-%d )

    # make a copy just in case
    if ! [ -f "$_bash.livy_copy" ]; then
        cp "$_bash" "$_bash.livy_copy"
    fi

    echo >> $_bash
    echo "###################################################" >> $_bash
    _str="# Livy"
    if [ "${_install_hadoop}" = "y" ]; then
        _str="$_str and Hadoop"
    fi
    _str="$_str environment variables"

    echo $_str >> $_bash
    echo "#" >> $_bash
    echo "# Script: installLivy.sh" >> $_bash
    echo "# Added on: $_today" >>$_bash
    echo >> $_bash

    if [ "${_install_hadoop}" = "y" ]; then
        echo "### HADOOP variables" >> $_bash
        echo "export HADOOP_HOME=$_hadoop_destination" >> $_bash
        echo "export PATH=\$HADOOP_HOME/bin:\$PATH" >> $_bash
    fi

    echo "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop/conf" >> $_bash
    echo >> $_bash
    echo "### LIVY variables" >> $_bash    
    echo "export LIVY_HOME=$_livy_destination" >> $_bash
    echo "export PATH=\$LIVY_HOME/bin:\$PATH" >> $_bash
}

# Clean up
function cleanUp() {
    cd ..
    rm -rf _temp
}

checkOS
printHeader
createTempDir
downloadThePackage $( echo "${_livy_binary}" )
unpack $( echo "${_livy_archive}" )
moveTheBinaries $( echo "${_livy_dir}" ) $( echo "${_livy_destination}" )

# create log directory inside the folder
mkdir -p "$_livy_destination/logs"

checkHadoop
installJupyterKernels
setSparkEnvironmentVariables
cleanUp