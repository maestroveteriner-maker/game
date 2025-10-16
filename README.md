# Flappy Anime (Codemagic self-building repo)

Bu depo, **Flutter kurmadan** Codemagic'te APK üretmeniz için hazırlandı.
Yapmanız gerekenler:
1. Bu klasörün içindekileri **GitHub** depo köküne yükleyin.
2. Codemagic > Add application > GitHub > bu depoyu seçin.
3. "Repository configuration (codemagic.yaml)" ile build başlatın.
4. Build bitince **Artifacts**'tan `app-release.apk`'yi indirin.

Oyun:
- Flappy Bird tarzı dokunmatik kontrol.
- Anime karakterli kuş (placeholder görseli). İstersen `assets/anime_bird.png` dosyasını kendi görselinizle değiştirin.
- Skor, çarpışma, yeniden başlatma diyalogu hazırdır.
