Currently the hash calculated is incorrect for the block. There is an off by 1
error somewhere - the last or first block is all zero.


- The block is saved out to priv/chunk0.bin 
- Setup a better test file
- Fix hash
- Download whole file


- Struct to represent a decoded torrent file 
- Think about struct type assertions
- Testing, bencode module


Tracker URLs
============

http://torrent.ubuntu.com:6969/announce?info_hash=J%03%DA9u%0CK%DD%0F%EB%B6m%8B%13%8C%EE%A5%99?%AA&peer_id=huswhudehuswhudehusw&port=51413&uploaded=0&downloaded=0&left=1157152768


Wiresharks
==========

/announce?info_hash=J%03%da9u%0cK%dd%0f%eb%b6m%8b%13%8c%ee%a5%99%3f%aa&peer_id=-TR2920-6ea03832320l&port=51413&uploaded=0&downloaded=0&left=1157627904&numwant=80&key=38153909&compact=1&supportcrypto=1&event=started  

/announce?info_hash=J%03%da9u%0cK%dd%0f%eb%b6m%8b%13%8c%ee%a5%99%3f%aa&peer_id=-TR2920-6ea03832320l&port=51413&uploaded=0&downloaded=0&left=1157152768&numwant=0&key=38153909&compact=1&supportcrypto=1&event=stopped  