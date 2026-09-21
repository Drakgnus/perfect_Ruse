# POC Multiplayer

Este prototipo e isolado do jogo principal em `multiplayer_poc/`. Ele demonstra a base de rede de alto nivel do Godot 4 com ENet, `MultiplayerSpawner` e `MultiplayerSynchronizer`.

- O host e o servidor autoritativo: apenas ele simula e publica posicao/rotacao.
- Cada cliente envia apenas o vetor de entrada para o servidor. O servidor confere que o remetente e dono daquele personagem antes de aceitar a entrada.
- `MultiplayerSpawner` cria/replica os personagens em `Players`; cada personagem contem um `MultiplayerSynchronizer` que replica o estado autorizado pelo servidor.
- Nao ha mecanicas de Perfect Ruse neste POC. Regras futuras continuam no GameManager do servidor; marcador de dinheiro, suspeita e deteccao nao foram portados.

## Teste local

1. Abra duas instancias do Godot apontando para este projeto (ou execute duas vezes a cena `res://multiplayer_poc/poc_multiplayer.tscn`).
2. Nas duas instancias, abra a cena do POC e rode-a com `F6`.
3. Na primeira instancia, clique em **Hospedar (porta 7007)**.
4. Na segunda, deixe `127.0.0.1` no campo de IP e clique em **Conectar**.
5. Use `WASD` em cada janela. Ambas devem exibir as capsulas se movendo de forma sincronizada; o host tambem recebe e valida a entrada do cliente.

A porta ENet fixa e `7007`. Para testar entre maquinas da mesma rede, informe no cliente o IP LAN do host e libere a porta UDP 7007 no firewall, se necessario.

## Validacao

Da raiz do projeto, execute:

```powershell
& '/d/Programas/Godot/Godot_v4.7-stable_win64.exe' --headless --path . --import
& '/d/Programas/Godot/Godot_v4.7-stable_win64.exe' --headless --path . --editor --quit-after 1200
```
