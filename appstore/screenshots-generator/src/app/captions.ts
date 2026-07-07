// =============================================================================
// Localized marketing captions for App Store screenshots.
//
// Only the marketing CHROME text is localized here (eyebrow labels, headlines,
// subtitles, the locked-app mock screen, the final feature pills + CTA).
// The raw in-app device captures under public/screenshots/<locale>/ are NOT
// affected by this file. "FitScroll" stays as the brand everywhere.
//
// Headlines are split into two lines (l1/l2) to mirror the existing layout's
// hard <br/>. Keep both lines SHORT so the big type does not overflow.
// =============================================================================

export type Locale =
  | "en"
  | "tr"
  | "pt-BR"
  | "es"
  | "fr"
  | "de"
  | "it"
  | "ja"
  | "ko"
  | "zh-Hans"
  | "ru";

export const LOCALES: Locale[] = [
  "en",
  "tr",
  "pt-BR",
  "es",
  "fr",
  "de",
  "it",
  "ja",
  "ko",
  "zh-Hans",
  "ru",
];

export type TwoLine = { l1: string; l2: string };

export type Captions = {
  // Card 01 — hero
  hero: {
    brand: string;
    head: TwoLine;
    sub: TwoLine;
  };
  // Card 02 — live pose detection
  camera: {
    label: string;
    head: TwoLine;
    sub: TwoLine;
  };
  // Card 03 — screen time lock (+ in-phone locked-app mock)
  lock: {
    label: string;
    head: TwoLine;
    sub: TwoLine;
    mock: {
      title: string; // "Time to Move 💪"
      body: string[]; // body lines (rendered with <br/> between)
      close: string;
    };
  };
  // Card 04 — earn minutes back
  earn: {
    label: string;
    head: TwoLine;
    sub: TwoLine;
  };
  // Card 05 — go lower / full range
  lower: {
    label: string;
    head: TwoLine;
    sub: TwoLine;
  };
  // Card 06 — analytics / streak
  analytics: {
    label: string;
    head: TwoLine;
    sub: TwoLine;
  };
  // Card 07 — final features card
  more: {
    head: TwoLine;
    sub: TwoLine;
    pills: string[]; // 8 feature pills
  };
};

export const CAPTIONS: Record<Locale, Captions> = {
  en: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Move to", l2: "unlock." },
      sub: { l1: "Turn doomscrolling into push-ups.", l2: "Every rep earns minutes back." },
    },
    camera: {
      label: "LIVE POSE DETECTION",
      head: { l1: "Your camera", l2: "counts every rep." },
      sub: { l1: "On-device AI. No videos recorded.", l2: "Nothing ever leaves your phone." },
    },
    lock: {
      label: "SCREEN TIME LOCK",
      head: { l1: "Lock the apps", l2: "that steal hours." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "Whatever keeps you scrolling." },
      mock: {
        title: "Time to Move 💪",
        body: ["This app is locked.", "Open FitScroll and finish an", "exercise to earn screen time."],
        close: "Close",
      },
    },
    earn: {
      label: "COIN THE TIME",
      head: { l1: "Every rep earns", l2: "minutes back." },
      sub: { l1: "Push-up or squat your way back", l2: "to your feed. Your choice, your grind." },
    },
    lower: {
      label: "GO LOWER",
      head: { l1: "Push deeper,", l2: "earn faster." },
      sub: { l1: "Full range counts.", l2: "Half reps don't." },
    },
    analytics: {
      label: "TRACK THE STREAK",
      head: { l1: "Watch the", l2: "streak grow." },
      sub: { l1: "Your reps and minutes, day by day.", l2: "See the loop you're breaking." },
    },
    more: {
      head: { l1: "Break the", l2: "dopamine loop." },
      sub: { l1: "Try free for 7 days.", l2: "Take your time back." },
      pills: [
        "On-device pose detection",
        "Live skeleton overlay",
        "Earn screen time",
        "Block distracting apps",
        "Daily usage limits",
        "History & analytics",
        "Smart unlock alerts",
        "100% private",
      ],
    },
  },

  tr: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Hareket et,", l2: "kilidi aç." },
      sub: { l1: "Sonsuz kaydırmayı şınava çevir.", l2: "Her tekrar dakika kazandırır." },
    },
    camera: {
      label: "CANLI POZ ALGILAMA",
      head: { l1: "Kameran", l2: "her tekrarı sayar." },
      sub: { l1: "Cihazda yapay zeka. Video kaydı yok.", l2: "Hiçbir şey telefonundan çıkmaz." },
    },
    lock: {
      label: "EKRAN SÜRESİ KİLİDİ",
      head: { l1: "Vaktini çalan", l2: "uygulamaları kilitle." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "Seni kaydırtan ne varsa." },
      mock: {
        title: "Hareket Zamanı 💪",
        body: ["Bu uygulama kilitli.", "FitScroll'u aç ve bir egzersizi", "bitirip ekran süresi kazan."],
        close: "Kapat",
      },
    },
    earn: {
      label: "ZAMANI KAZAN",
      head: { l1: "Her tekrar", l2: "dakika kazandırır." },
      sub: { l1: "Şınav ya da squat yap,", l2: "akışına dön. Senin tercihin." },
    },
    lower: {
      label: "DAHA DERİN İN",
      head: { l1: "Daha derine in,", l2: "daha hızlı kazan." },
      sub: { l1: "Tam hareket sayılır.", l2: "Yarım tekrarlar sayılmaz." },
    },
    analytics: {
      label: "SERİYİ TAKİP ET",
      head: { l1: "Serinin", l2: "büyümesini izle." },
      sub: { l1: "Tekrar ve dakikaların, gün gün.", l2: "Kırdığın döngüyü gör." },
    },
    more: {
      head: { l1: "Dopamin döngüsünü", l2: "kır." },
      sub: { l1: "7 gün ücretsiz dene.", l2: "Vaktini geri al." },
      pills: [
        "Cihazda poz algılama",
        "Canlı iskelet katmanı",
        "Ekran süresi kazan",
        "Dikkat dağıtanları engelle",
        "Günlük kullanım limiti",
        "Geçmiş & analiz",
        "Akıllı kilit uyarıları",
        "%100 gizli",
      ],
    },
  },

  "pt-BR": {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Mexa-se para", l2: "desbloquear." },
      sub: { l1: "Troque o scroll por flexões.", l2: "Cada repetição devolve minutos." },
    },
    camera: {
      label: "DETECÇÃO DE POSE AO VIVO",
      head: { l1: "Sua câmera", l2: "conta cada repetição." },
      sub: { l1: "IA no aparelho. Sem gravar vídeo.", l2: "Nada sai do seu celular." },
    },
    lock: {
      label: "BLOQUEIO DE TEMPO DE TELA",
      head: { l1: "Bloqueie os apps", l2: "que roubam horas." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "O que te prende no scroll." },
      mock: {
        title: "Hora de Mexer 💪",
        body: ["Este app está bloqueado.", "Abra o FitScroll e conclua um", "exercício para ganhar tempo de tela."],
        close: "Fechar",
      },
    },
    earn: {
      label: "RENDA EM TEMPO",
      head: { l1: "Cada repetição", l2: "devolve minutos." },
      sub: { l1: "Faça flexões ou agachamentos", l2: "e volte ao feed. Você escolhe." },
    },
    lower: {
      label: "DESÇA MAIS",
      head: { l1: "Desça mais fundo,", l2: "ganhe mais rápido." },
      sub: { l1: "Amplitude total conta.", l2: "Meias repetições não." },
    },
    analytics: {
      label: "ACOMPANHE A SEQUÊNCIA",
      head: { l1: "Veja a sequência", l2: "crescer." },
      sub: { l1: "Suas reps e minutos, dia a dia.", l2: "Veja o ciclo que está quebrando." },
    },
    more: {
      head: { l1: "Quebre o ciclo", l2: "da dopamina." },
      sub: { l1: "Teste grátis por 7 dias.", l2: "Recupere seu tempo." },
      pills: [
        "Detecção de pose no aparelho",
        "Esqueleto ao vivo",
        "Ganhe tempo de tela",
        "Bloqueie apps que distraem",
        "Limites diários de uso",
        "Histórico e análises",
        "Alertas de desbloqueio",
        "100% privado",
      ],
    },
  },

  es: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Muévete para", l2: "desbloquear." },
      sub: { l1: "Cambia el scroll por flexiones.", l2: "Cada rep te devuelve minutos." },
    },
    camera: {
      label: "DETECCIÓN DE POSE EN VIVO",
      head: { l1: "Tu cámara", l2: "cuenta cada rep." },
      sub: { l1: "IA en el dispositivo. Sin grabar vídeo.", l2: "Nada sale de tu teléfono." },
    },
    lock: {
      label: "BLOQUEO DE TIEMPO DE PANTALLA",
      head: { l1: "Bloquea las apps", l2: "que roban horas." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "Lo que te mantiene en el scroll." },
      mock: {
        title: "Hora de Moverse 💪",
        body: ["Esta app está bloqueada.", "Abre FitScroll y completa un", "ejercicio para ganar tiempo de pantalla."],
        close: "Cerrar",
      },
    },
    earn: {
      label: "CONVIERTE EN TIEMPO",
      head: { l1: "Cada rep te devuelve", l2: "minutos." },
      sub: { l1: "Haz flexiones o sentadillas", l2: "y vuelve al feed. Tú eliges." },
    },
    lower: {
      label: "BAJA MÁS",
      head: { l1: "Baja más,", l2: "gana más rápido." },
      sub: { l1: "El recorrido completo cuenta.", l2: "Las medias reps no." },
    },
    analytics: {
      label: "SIGUE LA RACHA",
      head: { l1: "Mira crecer", l2: "tu racha." },
      sub: { l1: "Tus reps y minutos, día a día.", l2: "Ve el bucle que estás rompiendo." },
    },
    more: {
      head: { l1: "Rompe el bucle", l2: "de la dopamina." },
      sub: { l1: "Pruébalo gratis 7 días.", l2: "Recupera tu tiempo." },
      pills: [
        "Detección de pose en el dispositivo",
        "Esqueleto en vivo",
        "Gana tiempo de pantalla",
        "Bloquea apps que distraen",
        "Límites diarios de uso",
        "Historial y análisis",
        "Alertas de desbloqueo",
        "100% privado",
      ],
    },
  },

  fr: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Bouge pour", l2: "débloquer." },
      sub: { l1: "Transforme le scroll en pompes.", l2: "Chaque rép. te rend des minutes." },
    },
    camera: {
      label: "DÉTECTION DE POSTURE EN DIRECT",
      head: { l1: "Ta caméra", l2: "compte chaque rép." },
      sub: { l1: "IA sur l'appareil. Aucune vidéo.", l2: "Rien ne quitte ton téléphone." },
    },
    lock: {
      label: "VERROU DE TEMPS D'ÉCRAN",
      head: { l1: "Verrouille les apps", l2: "qui volent tes heures." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "Tout ce qui te fait scroller." },
      mock: {
        title: "Il est temps de bouger 💪",
        body: ["Cette app est verrouillée.", "Ouvre FitScroll et termine un", "exercice pour gagner du temps d'écran."],
        close: "Fermer",
      },
    },
    earn: {
      label: "GAGNE DU TEMPS",
      head: { l1: "Chaque rép.", l2: "te rend des minutes." },
      sub: { l1: "Fais des pompes ou des squats", l2: "et reviens au fil. À toi de jouer." },
    },
    lower: {
      label: "DESCENDS PLUS BAS",
      head: { l1: "Descends plus,", l2: "gagne plus vite." },
      sub: { l1: "L'amplitude complète compte.", l2: "Les demi-rép. non." },
    },
    analytics: {
      label: "SUIS TA SÉRIE",
      head: { l1: "Regarde ta série", l2: "grandir." },
      sub: { l1: "Tes rép. et minutes, jour après jour.", l2: "Vois la boucle que tu brises." },
    },
    more: {
      head: { l1: "Brise la boucle", l2: "de la dopamine." },
      sub: { l1: "Essaie 7 jours gratuits.", l2: "Reprends ton temps." },
      pills: [
        "Détection de posture sur l'appareil",
        "Squelette en direct",
        "Gagne du temps d'écran",
        "Bloque les apps distrayantes",
        "Limites d'usage quotidiennes",
        "Historique et analyses",
        "Alertes de déverrouillage",
        "100% privé",
      ],
    },
  },

  de: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Beweg dich,", l2: "schalt frei." },
      sub: { l1: "Mach aus Scrollen Liegestütze.", l2: "Jede Wdh. bringt Minuten zurück." },
    },
    camera: {
      label: "LIVE-POSENERKENNUNG",
      head: { l1: "Deine Kamera", l2: "zählt jede Wdh." },
      sub: { l1: "KI auf dem Gerät. Keine Videos.", l2: "Nichts verlässt dein Handy." },
    },
    lock: {
      label: "BILDSCHIRMZEIT-SPERRE",
      head: { l1: "Sperre die Apps,", l2: "die Stunden klauen." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "Was dich am Scrollen hält." },
      mock: {
        title: "Zeit für Bewegung 💪",
        body: ["Diese App ist gesperrt.", "Öffne FitScroll und beende eine", "Übung für mehr Bildschirmzeit."],
        close: "Schließen",
      },
    },
    earn: {
      label: "ZEIT VERDIENEN",
      head: { l1: "Jede Wdh. bringt", l2: "Minuten zurück." },
      sub: { l1: "Liegestütze oder Kniebeugen,", l2: "zurück zum Feed. Deine Wahl." },
    },
    lower: {
      label: "GEH TIEFER",
      head: { l1: "Geh tiefer,", l2: "verdien schneller." },
      sub: { l1: "Volle Bewegung zählt.", l2: "Halbe Wdh. nicht." },
    },
    analytics: {
      label: "STREAK VERFOLGEN",
      head: { l1: "Sieh deinen", l2: "Streak wachsen." },
      sub: { l1: "Deine Wdh. und Minuten, Tag für Tag.", l2: "Sieh die Schleife, die du brichst." },
    },
    more: {
      head: { l1: "Durchbrich die", l2: "Dopamin-Schleife." },
      sub: { l1: "7 Tage gratis testen.", l2: "Hol dir deine Zeit zurück." },
      pills: [
        "Posenerkennung auf dem Gerät",
        "Live-Skelett-Overlay",
        "Bildschirmzeit verdienen",
        "Ablenkende Apps sperren",
        "Tägliche Nutzungslimits",
        "Verlauf & Analysen",
        "Smarte Entsperr-Hinweise",
        "100% privat",
      ],
    },
  },

  it: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Muoviti per", l2: "sbloccare." },
      sub: { l1: "Trasforma lo scroll in flessioni.", l2: "Ogni rip. ti ridà minuti." },
    },
    camera: {
      label: "RILEVAMENTO POSA DAL VIVO",
      head: { l1: "La tua fotocamera", l2: "conta ogni rip." },
      sub: { l1: "IA sul dispositivo. Nessun video.", l2: "Niente lascia il tuo telefono." },
    },
    lock: {
      label: "BLOCCO TEMPO DI SCHERMO",
      head: { l1: "Blocca le app", l2: "che rubano ore." },
      sub: { l1: "Instagram. TikTok. YouTube. X.", l2: "Ciò che ti tiene a scrollare." },
      mock: {
        title: "È ora di muoversi 💪",
        body: ["Questa app è bloccata.", "Apri FitScroll e completa un", "esercizio per guadagnare tempo."],
        close: "Chiudi",
      },
    },
    earn: {
      label: "GUADAGNA TEMPO",
      head: { l1: "Ogni rip.", l2: "ti ridà minuti." },
      sub: { l1: "Fai flessioni o squat", l2: "e torna al feed. Scegli tu." },
    },
    lower: {
      label: "SCENDI DI PIÙ",
      head: { l1: "Scendi di più,", l2: "guadagna prima." },
      sub: { l1: "L'escursione completa conta.", l2: "Le mezze rip. no." },
    },
    analytics: {
      label: "SEGUI LA SERIE",
      head: { l1: "Guarda la serie", l2: "crescere." },
      sub: { l1: "Le tue rip. e i minuti, giorno per giorno.", l2: "Vedi il ciclo che stai spezzando." },
    },
    more: {
      head: { l1: "Spezza il ciclo", l2: "della dopamina." },
      sub: { l1: "Provalo gratis per 7 giorni.", l2: "Riprenditi il tuo tempo." },
      pills: [
        "Rilevamento posa sul dispositivo",
        "Scheletro dal vivo",
        "Guadagna tempo di schermo",
        "Blocca app che distraggono",
        "Limiti d'uso giornalieri",
        "Cronologia e analisi",
        "Avvisi di sblocco",
        "100% privato",
      ],
    },
  },

  ja: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "動いて", l2: "ロック解除。" },
      sub: { l1: "だらだらスクロールを腕立てに。", l2: "1回ごとに時間が戻る。" },
    },
    camera: {
      label: "ライブ姿勢検出",
      head: { l1: "カメラが", l2: "回数を数える。" },
      sub: { l1: "端末内AI。動画は記録しない。", l2: "データは端末から出ない。" },
    },
    lock: {
      label: "スクリーンタイムロック",
      head: { l1: "時間を奪うアプリを", l2: "ロック。" },
      sub: { l1: "Instagram、TikTok、YouTube、X。", l2: "スクロールさせる全部を。" },
      mock: {
        title: "動く時間です 💪",
        body: ["このアプリはロック中。", "FitScrollを開いて運動を終え、", "スクリーンタイムを獲得しよう。"],
        close: "閉じる",
      },
    },
    earn: {
      label: "時間を稼ぐ",
      head: { l1: "1回ごとに", l2: "時間が戻る。" },
      sub: { l1: "腕立てかスクワットで", l2: "フィードへ。選ぶのは君。" },
    },
    lower: {
      label: "もっと深く",
      head: { l1: "深く沈むほど、", l2: "速く稼ぐ。" },
      sub: { l1: "フルレンジだけカウント。", l2: "ハーフはノーカウント。" },
    },
    analytics: {
      label: "連続記録を追う",
      head: { l1: "連続記録が", l2: "伸びていく。" },
      sub: { l1: "回数と分を、毎日記録。", l2: "断ち切るループが見える。" },
    },
    more: {
      head: { l1: "ドーパミンの", l2: "ループを断つ。" },
      sub: { l1: "7日間無料でお試し。", l2: "自分の時間を取り戻そう。" },
      pills: [
        "端末内の姿勢検出",
        "ライブ骨格表示",
        "スクリーンタイムを獲得",
        "気が散るアプリをブロック",
        "1日の利用制限",
        "履歴と分析",
        "スマート解除通知",
        "100%プライベート",
      ],
    },
  },

  ko: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "움직여서", l2: "잠금 해제." },
      sub: { l1: "무한 스크롤을 푸시업으로.", l2: "한 번마다 시간이 돌아와요." },
    },
    camera: {
      label: "실시간 자세 인식",
      head: { l1: "카메라가", l2: "횟수를 세요." },
      sub: { l1: "기기 내 AI. 영상 녹화 없음.", l2: "어떤 것도 폰을 벗어나지 않아요." },
    },
    lock: {
      label: "화면 시간 잠금",
      head: { l1: "시간을 훔치는", l2: "앱을 잠가요." },
      sub: { l1: "인스타그램, 틱톡, 유튜브, X.", l2: "당신을 붙잡는 모든 것." },
      mock: {
        title: "움직일 시간 💪",
        body: ["이 앱은 잠겨 있어요.", "FitScroll을 열고 운동을 끝내", "화면 시간을 얻으세요."],
        close: "닫기",
      },
    },
    earn: {
      label: "시간을 벌기",
      head: { l1: "한 번마다", l2: "시간이 돌아와요." },
      sub: { l1: "푸시업이나 스쿼트로", l2: "피드로 복귀. 선택은 당신." },
    },
    lower: {
      label: "더 깊게",
      head: { l1: "더 깊게,", l2: "더 빨리 벌어요." },
      sub: { l1: "전체 동작만 인정.", l2: "반쪽 동작은 제외." },
    },
    analytics: {
      label: "연속 기록 추적",
      head: { l1: "연속 기록이", l2: "자라나요." },
      sub: { l1: "횟수와 분을, 매일.", l2: "끊어내는 고리를 확인." },
    },
    more: {
      head: { l1: "도파민 고리를", l2: "끊어요." },
      sub: { l1: "7일 무료 체험.", l2: "당신의 시간을 되찾으세요." },
      pills: [
        "기기 내 자세 인식",
        "실시간 스켈레톤",
        "화면 시간 획득",
        "방해 앱 차단",
        "일일 사용 제한",
        "기록 및 분석",
        "스마트 잠금 해제 알림",
        "100% 비공개",
      ],
    },
  },

  "zh-Hans": {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "运动即可", l2: "解锁。" },
      sub: { l1: "把刷屏变成俯卧撑。", l2: "每做一次，时间就回来一点。" },
    },
    camera: {
      label: "实时姿势检测",
      head: { l1: "你的相机", l2: "数清每一次。" },
      sub: { l1: "设备本地 AI，不录制视频。", l2: "数据从不离开你的手机。" },
    },
    lock: {
      label: "屏幕时间锁定",
      head: { l1: "锁定偷走", l2: "时间的应用。" },
      sub: { l1: "Instagram、TikTok、YouTube、X。", l2: "一切让你停不下来的。" },
      mock: {
        title: "该动一动了 💪",
        body: ["此应用已锁定。", "打开 FitScroll 完成一组运动，", "即可赚取屏幕使用时间。"],
        close: "关闭",
      },
    },
    earn: {
      label: "把时间赚回来",
      head: { l1: "每做一次", l2: "都赚回时间。" },
      sub: { l1: "做俯卧撑或深蹲，", l2: "回到信息流。你说了算。" },
    },
    lower: {
      label: "蹲得更低",
      head: { l1: "蹲得更深，", l2: "赚得更快。" },
      sub: { l1: "全程动作才算数。", l2: "半程不计入。" },
    },
    analytics: {
      label: "追踪连续记录",
      head: { l1: "看连续记录", l2: "不断增长。" },
      sub: { l1: "每天的次数与分钟数。", l2: "看清你正在打破的循环。" },
    },
    more: {
      head: { l1: "打破多巴胺", l2: "循环。" },
      sub: { l1: "7 天免费试用。", l2: "把时间夺回来。" },
      pills: [
        "设备本地姿势检测",
        "实时骨架叠加",
        "赚取屏幕时间",
        "屏蔽分心应用",
        "每日使用限额",
        "历史与分析",
        "智能解锁提醒",
        "100% 隐私",
      ],
    },
  },

  ru: {
    hero: {
      brand: "FITSCROLL",
      head: { l1: "Двигайся,", l2: "чтобы открыть." },
      sub: { l1: "Преврати скроллинг в отжимания.", l2: "Каждый повтор возвращает минуты." },
    },
    camera: {
      label: "ЖИВОЕ РАСПОЗНАВАНИЕ ПОЗ",
      head: { l1: "Камера считает", l2: "каждый повтор." },
      sub: { l1: "ИИ на устройстве. Видео не пишется.", l2: "Ничего не покидает телефон." },
    },
    lock: {
      label: "БЛОКИРОВКА ЭКРАННОГО ВРЕМЕНИ",
      head: { l1: "Блокируй приложения,", l2: "что крадут часы." },
      sub: { l1: "Instagram, TikTok, YouTube, X.", l2: "Всё, что держит тебя в ленте." },
      mock: {
        title: "Пора двигаться 💪",
        body: ["Это приложение заблокировано.", "Открой FitScroll и заверши", "упражнение ради экранного времени."],
        close: "Закрыть",
      },
    },
    earn: {
      label: "ЗАРАБОТАЙ ВРЕМЯ",
      head: { l1: "Каждый повтор", l2: "возвращает минуты." },
      sub: { l1: "Отжимания или приседания —", l2: "и снова в ленту. Твой выбор." },
    },
    lower: {
      label: "ОПУСКАЙСЯ НИЖЕ",
      head: { l1: "Глубже —", l2: "быстрее заработок." },
      sub: { l1: "Считается полная амплитуда.", l2: "Половинчатые повторы — нет." },
    },
    analytics: {
      label: "СЛЕДИ ЗА СЕРИЕЙ",
      head: { l1: "Смотри, как растёт", l2: "твоя серия." },
      sub: { l1: "Повторы и минуты, день за днём.", l2: "Виден цикл, который ты рвёшь." },
    },
    more: {
      head: { l1: "Разорви", l2: "петлю дофамина." },
      sub: { l1: "7 дней бесплатно.", l2: "Верни своё время." },
      pills: [
        "Распознавание поз на устройстве",
        "Живой скелет поверх кадра",
        "Зарабатывай экранное время",
        "Блокируй отвлекающие приложения",
        "Дневные лимиты",
        "История и аналитика",
        "Умные напоминания",
        "100% приватно",
      ],
    },
  },
};

export function resolveLocale(raw: string | null | undefined): Locale {
  if (raw && (LOCALES as string[]).includes(raw)) return raw as Locale;
  return "en";
}
