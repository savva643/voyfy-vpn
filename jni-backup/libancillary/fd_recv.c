#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>

#include "ancillary.h"

int ancil_recv_fd(int sock, int *fd) {
    struct msghdr msg;
    struct cmsghdr *cmsg;
    char buf[CMSG_SPACE(sizeof(int))];
    struct iovec iov[1];
    char dummy;
    int ret;
    int nfd;

    iov[0].iov_base = &dummy;
    iov[0].iov_len = 1;

    msg.msg_name = NULL;
    msg.msg_namelen = 0;
    msg.msg_iov = iov;
    msg.msg_iovlen = 1;
    msg.msg_control = buf;
    msg.msg_controllen = sizeof(buf);

    ret = recvmsg(sock, &msg, 0);
    if (ret == -1) {
        return -1;
    }

    cmsg = CMSG_FIRSTHDR(&msg);
    if (cmsg == NULL) {
        return -1;
    }
    if (cmsg->cmsg_level != SOL_SOCKET || cmsg->cmsg_type != SCM_RIGHTS) {
        return -1;
    }
    nfd = *((int *) CMSG_DATA(cmsg));
    if (nfd < 0) {
        return -1;
    }
    *fd = nfd;
    return 0;
}
