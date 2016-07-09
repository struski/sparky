# Sparky

Helper scripts for installing Apache Spark and Spark Notebook for my personal experimentation

In order to change versions installed edit *_URL and *_FILENAME variables at the beggining of the script

Tested on CentOS 7. Use at your own responsibility.

## spark_install.sh

1. Downloads Apache Spark
2. Extracts files to /opt/spark (or spark1 if spark already exists, or spark2 etc)
3. Adds environment variables to ~/.bash_profile
4. Adds command to launch and stop Master <pre>sparky start</pre> <pre>sparky stop</pre>
5. Displays some info on usage

## spark_notebook_install.sh

1. Downloads Spark Notebook
2. Extracts files to /opt/spark-notebook
3. Adds environment variables to ~/.bash_profile 
4. Adds command to launch Spark Notebook <pre>sparky start-notebook</pre>
5. Displays some info on usage

## zeppelin_install.sh

1. Downloads Apache Zeppelin
2. Extracts files to /opt/zeppelin
3. Adds environment variables to ~/.bash_profile 
4. Adds command to launch and stop Zeppelin <pre>sparky start-zeppelin</pre> <pre>sparky stop-zeppelin</pre>
5. Displays some info on usage 


## Notes

If you install mutliple times you will always have sparky command pointing to the last install.
This way you can update the version by editing variables at the top of the script and running it again.

## URLs to get new versions from

http://spark.apache.org/downloads.html

http://spark-notebook.io

http://zeppelin.apache.org/

