
#ifndef _MY_MESSAGES_HEADER_
#define _MY_MESSAGES_HEADER_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <sys/stat.h>
#include <grp.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/un.h>

#define UDS_DEVICE			      "/home/pi/wecker/wecker.uds"

namespace as {

  class MESSAGES {

    char cmdMessage[MAX_MESSAGE_LENGTH];
    bool cmdMessageComplete;
    int fdm;
    int sock;
    struct timeval timeout;
    uint timeoutDelay, timeoutDelayUs; //s
    fd_set readfd;

  public:
    MESSAGES(uint delay=0, uint udelay=0) {
      fdm=-1;
      sock=-1;
      timeoutDelay = delay;
      timeoutDelayUs = udelay;
      cmdMessage[0]=0x0;
      cmdMessageComplete=false;
    }
    ~MESSAGES() {
      close(fdm);
    }

    void begin() {
      // fdm = createPTY();
      fdm = createSocket(sock);
      if(fdm==-1) printf("create failed\n");
    }

    bool poll() {
      int c=0,len=0;
      int selret;

      FD_ZERO(&readfd);
      FD_SET(fdm, &readfd);
      timeout.tv_sec = timeoutDelay; timeout.tv_usec = timeoutDelayUs;

      selret = select(fdm+1, &readfd, NULL, NULL, &timeout);
      if(selret > 0 && FD_ISSET(fdm,&readfd)) {
        len = strlen(cmdMessage);
        c = recv(fdm, cmdMessage+len, MAX_MESSAGE_LENGTH-len, 0);
        if(c == -1 || c == 0) {
          printf("client disconnected\n");fflush(stdout);
          cmdMessage[0]=0x0;
          return false;
        }
        len += c;
        cmdMessage[len] = 0x0;
        //printf("read: %d pos: %d len: %d <%s>\n",c,len,MAX_MESSAGE_LENGTH-len,cmdMessage);fflush(stdout);
        if(cmdMessage[len-1] == '\n' || cmdMessage[len-1] == '\r' || len == MAX_MESSAGE_LENGTH) { //complete
          cmdMessage[len-1] = 0x0;
          cmdMessageComplete=true;
        }
      }
      return true;
    }

    void sendMessage(char *buf, unsigned int len) {
      send (fdm, buf, len, 0);
      send (fdm, "\n",1, 0);
    }

    bool getMessage(char *buffer) {
      if(cmdMessageComplete) {
        memcpy(buffer, cmdMessage,strlen(cmdMessage)+1);
        cmdMessageComplete=false;
        cmdMessage[0] = 0x0;
        return true;
      }
      return false;
    }

  private:
    void setPermissons() {
      //set file group and read/write permissions
      chmod(UDS_DEVICE ,S_IWUSR|S_IRUSR|S_IRGRP|S_IWGRP);
      struct group  *grp;
      grp = getgrnam("dialout");
      chown(UDS_DEVICE, 0, grp->gr_gid);
    }

    int createSocket(int create_socket=-1) { //Unix Device Socket
      int new_socket;
      struct sockaddr_un address; socklen_t addrlen;

      if(create_socket==-1 && sock!=-1) {
        close(sock);
        sock=-1;
      }

      if(sock==-1) {
        if((sock=socket(AF_LOCAL, SOCK_STREAM, 0)) < 0) {
          printf ("create socket failed\n");
          return -1;
        }

        unlink(UDS_DEVICE);

        address.sun_family = AF_LOCAL;
        strcpy(address.sun_path, UDS_DEVICE);
        if (bind ( sock, (struct sockaddr *) &address, sizeof (address)) != 0) {
          printf("socket busy!\n");
          return -1;
        }

        setPermissons();
        printf("Domain Socket --> %s\n",UDS_DEVICE);
      }

      if(listen (sock, 1) != 0) {
        printf( "listen failed!\n");
        return -1;
      }

      addrlen = sizeof (struct sockaddr_in);
      printf("waiting for client\n");
      if((new_socket = accept ( sock, (struct sockaddr *) &address, &addrlen )) == -1) {
        printf("accept failed!\n");
        fdm=-1;
        return fdm;
      }

      fdm = new_socket;
      return fdm;
    }
  };
  extern MESSAGES Msg;
}

#endif
