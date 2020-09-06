To start
    
    docker-compose up

Access web panel via

    http://192.168.1.7:9091/transmission/web/


Install the transmission client and use it to create a new torrent file
for testing.

Create a new torrent and set the tracker url to:

    http://192.168.1.7:6969/announce


Upload the torrent file to the web verson of transmission running on
192.168.1.7 and check that the upload works. 

Find the created .torrent file and copy it to the priv folder

Notes:

You can access the stats page at: 

http://192.168.1.7:6969/stats?mode=everything


Sources:

- http://erdgeist.org/arts/software/opentracker/
- https://hub.docker.com/r/lednerb/opentracker-docker/
- https://github.com/transmission/transmission

