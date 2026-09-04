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
sudo ./install-online.sh agilizesolucoes/bchat-whitelabel:1.1.1 8888
```

Se o repositorio ja estiver clonado, execute somente:

```bash
cd /var/www/bchat-whitelabel-installer
sudo chmod +x install-online.sh bchatctl
sudo ./install-online.sh agilizesolucoes/bchat-whitelabel:1.1.1 8888
```

O comando faz o pull da imagem, cria os segredos locais, sobe os volumes
persistentes e deixa o configurador em `http://IP_DO_SERVIDOR:8080/__bchat`.
O segundo argumento e somente a porta publica escolhida, neste exemplo `8888`.
O dominio e definido
depois, dentro do configurador visual.

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
