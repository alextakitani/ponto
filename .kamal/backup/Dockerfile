# Imagem do acessório de backup (kamal-backup) + openssh + wrapper SFTP.
# A imagem oficial (Debian trixie) não traz `ssh`, que o restic precisa pro backend
# SFTP da Hetzner Storage Box. Além do openssh-client, embutimos um wrapper `ssh`
# à frente no PATH que injeta porta 23 + chave dedicada + known_hosts — assim o
# restic acessa o repo `sftp:` sem flags extras (o gem não expõe sftp.command).
FROM ghcr.io/crmne/kamal-backup:0.4.0

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssh-client \
  && rm -rf /var/lib/apt/lists/*

# Wrapper: o Kamal monta a chave read-only com permissão 0755 (o ssh recusa
# "too open"). O wrapper COPIA a chave pra um local com 0600 e chama o ssh com
# porta 23 + known_hosts. Toda chamada `ssh` do restic passa por aqui.
RUN printf '%s\n' \
  '#!/bin/sh' \
  'K=/tmp/.bkkey' \
  'cp /root/.ssh/id_ed25519 "$K" 2>/dev/null && chmod 600 "$K"' \
  'exec /usr/bin/ssh -p 23 -i "$K" -o IdentitiesOnly=yes -o UserKnownHostsFile=/root/.ssh/known_hosts -o StrictHostKeyChecking=accept-new "$@"' \
  > /usr/local/bin/ssh \
  && chmod +x /usr/local/bin/ssh
