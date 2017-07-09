FROM centos

# Ideas from https://github.com/jtgasper3/docker-images/blob/master/389-ds/Dockerfile

RUN curl -O https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm\
 && rpm -Uvh epel-release-latest-7.noarch.rpm\
 && rm -f epel-release-latest-7.noarch.rpm

RUN yum update  -y\
 && yum install -y\
 389-ds-base\
 openssl\
 && yum clean all

# Basicaly
# * turn off selinux
# * disable hostname check (most important, as this is absolutely unreliable in a container)
# * disable restart of Services, makes no sense during container build
# * disable reloading of systemd setting. also makes no sense during container build

RUN cd /usr/lib64/dirsrv/perl\
 && sed -i.orig  's/checkHostname {/checkHostname {\nreturn();/g' DSUtil.pm \
 && sed -i.orig  's/updateSelinuxPolicy($inf);//g'  DSCreate.pm  DSUpdate.pm \
 && sed -i.orig  's/DSCreate::updateSelinuxPolicy($inf);//g' DSMigration.pm \
 && sed -i.orig2 '/if (@errs = startServer($inf))/,/}/d' DSCreate.pm \
 && sed -i.orig3 's:/bin/systemctl --system daemon-reload:/bin/echo /bin/systemctl --system daemon-reload:g' DSCreate.pm

COPY install/*.sh /
COPY install/*.ldif  /

CMD  [ "/init.sh" ]

EXPOSE 389 636
