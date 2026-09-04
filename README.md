# BChat White-label

Pacote de instalacao do cliente. Esta entrega usa uma imagem Docker assinada e
nao contem o codigo-fonte do produto.

## Instalacao online (Docker Hub)

Execute este bloco no servidor para baixar o instalador e iniciar o BChat:

```bash
cd /var/www
git clone --depth 1 https://github.com/alexmenin/bchat-whitelabel-installer.git bchat-whitelabel-installer
cd bchat-whitelabel-installer
sudo chmod +x install-online.sh bchatctl
sudo ./install-online.sh agilizesolucoes/bchat-whitelabel:1.1.7 3388
```

Para atualizar uma instalacao existente sem disputar a porta, use:

```bash
cd /var/www/bchat-whitelabel-installer
sudo git pull
sudo ./bchatctl update-online agilizesolucoes/bchat-whitelabel:1.1.7
```

Esse comando troca somente o container BChat, preserva os volumes e aguarda o
healthcheck interno. Em caso de falha, restaura o `.env` anterior.

Se o configurador informar que a sessao expirou, execute `sudo ./bchatctl
setup-code` e clique em `Validar codigo novamente` na tela. Isso nao exige
apagar volumes nem reinstalar o sistema.

Se o codigo continuar sendo recusado, gere um novo codigo diretamente no
volume persistente:

```bash
sudo ./bchatctl reset-setup-code
```

Se o repositorio ja estiver clonado, execute somente:

```bash
cd /var/www/bchat-whitelabel-installer
sudo chmod +x install-online.sh bchatctl
sudo ./install-online.sh agilizesolucoes/bchat-whitelabel:1.1.6 3388
```

O comando faz o pull da imagem, cria os segredos locais, sobe os volumes
persistentes e deixa o configurador em `http://IP_DO_SERVIDOR:3388/__bchat`.
O segundo argumento e somente a porta publica escolhida, neste exemplo `3388`.
O IP publico do servidor e aplicado automaticamente ao SIP na primeira
instalacao. Um valor SIP personalizado ja existente no `.env` e preservado. O dominio e definido
depois, dentro do configurador visual.

O instalador verifica se a porta escolhida esta livre antes de baixar a imagem
ou subir o container. Se ela estiver ocupada, ele informa o processo e encerra
sem alterar a instalacao. Para continuar, escolha outra porta:

A versao `1.1.7` inclui a recuperacao explicita da sessao do configurador,
o binario FFmpeg exigido pelo backend e mantem a faixa RTP padrao em
`10000-10100`, evitando
que o Docker tente publicar milhares de portas. Uma faixa personalizada no
`.env` e preservada.

```bash
sudo ./install-online.sh agilizesolucoes/bchat-whitelabel:1.1.7 3388
```

Se uma tentativa anterior ja criou o projeto, entre na pasta e execute:

```bash
cd /var/www/bchat-whitelabel-installer
sudo ./install-online.sh agilizesolucoes/bchat-whitelabel:1.1.7 3388
sudo docker compose ps
sudo docker compose logs --tail=80 bchat
```

Use `sudo docker compose ps -a` para visualizar tambem containers que foram
encerrados durante a inicializacao.

## Instalacao offline

1. Instale a imagem `bchat-appliance:<versao>` fornecida pelo vendedor:

```bash
docker load -i bchat-appliance-1.0.0.tar
```

2. Execute o instalador como root:

```bash
sudo ./install.sh
```

3. Consulte o codigo temporario e abra o configurador local:

```bash
sudo ./bchatctl setup-code
```

Abra `http://127.0.0.1:8080/__bchat` no servidor ou use um tunel SSH. Ative a
licenca, informe a marca e os dominios. O sistema nao libera a aplicacao antes
da validacao da licenca.

4. Publique o dominio:

```bash
sudo ./bchatctl proxy install
sudo ./bchatctl tls enable
sudo ./bchatctl status
```

O `proxy install` cria somente o arquivo deste produto em
`/etc/nginx/sites-available/bchat-whitelabel.conf`, valida com `nginx -t` e
recarrega o Nginx. O `tls enable` usa o plugin Nginx do Certbot nos dominios
configurados.

## Comandos de manutencao

```bash
sudo ./bchatctl logs
sudo ./bchatctl diagnostics
sudo ./bchatctl update
sudo ./bchatctl backup ./backup
```

Nao remova os volumes Docker: `bchat_data`, `bchat_sessions`, `bchat_public`,
`bchat_temp` e `bchat_reports` contem dados da instalacao.

## Limite de protecao do codigo

O cliente recebe uma imagem sem fontes TypeScript/Dart e sem source maps. Como o
frontend executa no navegador, parte do JavaScript necessariamente pode ser
inspecionada pelo navegador. A protecao comercial real e feita pela imagem
privada, licenca assinada, atualizacoes assinadas e controle de acesso ao
registro. Nao prometa impossibilidade absoluta de engenharia reversa para quem
tem acesso root ao host.
