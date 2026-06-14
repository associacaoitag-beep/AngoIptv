# AngoMovie IPTV

App de TV ao vivo no estilo Netflix para Android. Interface moderna com carregamento de canais M3U, player de vídeo integrado, busca e navegação por categorias.

## 🎯 Funcionalidades

- **Interface Netflix**: Tela principal com linhas horizontais por categoria
- **Player de Vídeo**: Suporte a HLS, MP4, TS com todos os codecs (H.264, H.265, AAC, AC-3)
- **Tela de Carregamento**: Animação estilo streaming com indicador circular
- **Cache Local**: Canais salvos com Hive (sem re-download a cada abertura)
- **Busca**: Filtro em tempo real por nome/categoria (debounce 350ms)
- **Aviso de Privacidade**: Exibido na primeira abertura
- **Segurança**: R8/ProGuard ativado no release, rede restrita a domínios autorizados
- **Configurações**: Gerenciar cache, privacidade e segurança de conexão

## 📦 Versão

- **Versão**: 1.2.0
- **Build**: 3
- **Android mínimo**: 5.0 (API 21)

## 🛠️ Tecnologias

| Componente       | Tecnologia         |
|------------------|--------------------|
| Framework        | Flutter 3.35.4     |
| Linguagem        | Dart 3.9.2         |
| Player           | video_player 2.x   |
| Cache            | Hive 2.2.3         |
| Imagens          | cached_network_image |
| Estado           | Provider 6.x       |
| HTTP             | http + dio         |
| Backend          | FastAPI + httpx    |

## 🚀 Build

```bash
# Instalar dependências
flutter pub get

# Build APK release
flutter clean
flutter pub get
flutter build apk --release

# APK gerado em:
# build/app/outputs/flutter-apk/app-release.apk

# Se quiser instalar direto no aparelho ligado
flutter install
```

## 🔧 Backend (Opcional)

```bash
cd backend/
pip install -r requirements.txt
python server.py
```

API disponível em `http://localhost:8000`:
- `GET /api/channels` – Lista de canais ao vivo
- `GET /api/categories` – Categorias disponíveis
- `GET /api/data-version` – Versão dos dados (para verificar atualizações)
- `GET /api/health` – Status do servidor

## 📱 Estrutura do Projeto

```
lib/
├── main.dart                 # Ponto de entrada
├── models/
│   ├── channel.dart          # Modelo de canal
│   └── channel.g.dart        # Adaptador Hive (gerado)
├── services/
│   ├── channel_service.dart  # Cache e fetch de canais
│   └── m3u_parser.dart       # Parser M3U+ com filtros
├── providers/
│   └── channel_provider.dart # Estado global
├── screens/
│   ├── splash_screen.dart    # Tela de carregamento
│   ├── home_screen.dart      # Tela principal
│   ├── player_screen.dart    # Player de vídeo
│   ├── settings_screen.dart  # Configurações
│   └── privacy_screen.dart   # Aviso de privacidade
├── widgets/
│   ├── channel_card.dart     # Card de canal
│   ├── featured_channel.dart # Destaque principal
│   └── search_bar_widget.dart # Barra de busca
└── utils/
    ├── app_colors.dart       # Paleta de cores
    └── app_theme.dart        # Tema escuro Netflix
```

## 🔒 Segurança

- **R8/ProGuard**: Minificação e obfuscação no release
- **Rede**: `network_security_config.xml` restringe cleartext a domínios autorizados
- **Sem Logs**: `Log.d` removido via ProGuard no release
- **Dados Locais**: Hive com dados estruturados (não em texto plano)

## 📡 Fonte de Dados

- **M3U**: `http://nitidez.pro:80/get.php?username=Marcio&password=123456&type=m3u_plus`
- 
- **Cache TTL**: Indefinido (só atualiza quando o usuário solicitar)
