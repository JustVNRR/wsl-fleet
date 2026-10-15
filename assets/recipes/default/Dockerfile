FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN userdel -r ubuntu 2>/dev/null || true

RUN rm -f /etc/dpkg/dpkg.cfg.d/*

RUN touch /etc/skel/.zshrc \
    && mkdir -p /etc/skel/.ssh \
    && mkdir -p /etc/skel/projects \
    && chmod 700 /etc/skel/.ssh \
    && chown -R root:root /etc/skel

COPY onboarding.sh /root/onboarding.sh
RUN chmod 755 /root/onboarding.sh \
    && echo /root/onboarding.sh >> /root/.bashrc

CMD ["/bin/bash"]
