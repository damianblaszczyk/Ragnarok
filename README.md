# Ragnarok

**Fast** and **high performance** tunnel to IRC connection. This script not using fork method, all implementation is on IO::Handle. All you have to do change host and port to your IRC network. 🚀

For example using chat.idx.pl IRC network.

**Ragnarok** guard all sockets, remove broken sockets, check timeout for all sockets, repair broken line when not end with new line character (LF) and more. Now you can have multiple connection on your server, new PID not eat your CPU because does not exist! 

<img width="1088" alt="Zrzut ekranu 2022-11-1 o 23 43 10" src="https://user-images.githubusercontent.com/60239406/199355952-f5b04b53-32a8-46ae-9e9e-1176c0aa6618.png">
