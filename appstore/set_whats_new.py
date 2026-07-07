#!/usr/bin/env python3
"""Set the 'What's New' text on every localization of the editable version.

Usage: python3 set_whats_new.py [version]   (default 1.1.0)
"""

import json
import sys

import asc_client as asc

VERSION = sys.argv[1] if len(sys.argv) > 1 else "1.1.0"
EDITABLE_STATES = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED",
                   "REJECTED", "METADATA_REJECTED")

WHATS_NEW = {
    "en-US": "• Compete on the new leaderboard\n• Challenge your friends — and get notified the moment they accept\n• Push notifications for challenges\n• Fresh new design with sounds and haptics\n• See your protected apps at a glance\n• Bug fixes and performance improvements",
    "tr": "• Yeni liderlik tablosunda yarış\n• Arkadaşlarına meydan oku — kabul ettikleri anda bildirim al\n• Meydan okumalar için anlık bildirimler\n• Ses ve titreşim efektleriyle yepyeni tasarım\n• Korunan uygulamalarını tek bakışta gör\n• Hata düzeltmeleri ve performans iyileştirmeleri",
    "de-DE": "• Tritt auf dem neuen Leaderboard an\n• Fordere deine Freunde heraus — mit Benachrichtigung, sobald sie annehmen\n• Push-Benachrichtigungen für Challenges\n• Frisches Design mit Sounds und Haptik\n• Deine geschützten Apps auf einen Blick\n• Fehlerbehebungen und Leistungsverbesserungen",
    "fr-FR": "• Affronte les autres sur le nouveau classement\n• Défie tes amis — et sois notifié dès qu'ils acceptent\n• Notifications push pour les défis\n• Nouveau design avec sons et vibrations\n• Tes apps protégées en un coup d'œil\n• Corrections de bugs et améliorations",
    "es-ES": "• Compite en la nueva clasificación\n• Reta a tus amigos y recibe una notificación cuando acepten\n• Notificaciones push para los retos\n• Nuevo diseño con sonidos y hápticos\n• Tus apps protegidas de un vistazo\n• Corrección de errores y mejoras de rendimiento",
    "it": "• Competi nella nuova classifica\n• Sfida i tuoi amici — con notifica appena accettano\n• Notifiche push per le sfide\n• Nuovo design con suoni e feedback aptico\n• Le tue app protette a colpo d'occhio\n• Correzioni di bug e miglioramenti",
    "pt-BR": "• Dispute o novo ranking\n• Desafie seus amigos — e seja notificado assim que aceitarem\n• Notificações push para desafios\n• Novo visual com sons e vibrações\n• Seus apps protegidos em um relance\n• Correções de bugs e melhorias de desempenho",
    "ru": "• Соревнуйтесь в новом рейтинге\n• Бросайте вызов друзьям — с уведомлением, как только они примут\n• Push-уведомления о вызовах\n• Новый дизайн со звуками и вибрацией\n• Защищённые приложения — с первого взгляда\n• Исправления ошибок и улучшения производительности",
    "ja": "• 新しいランキングで競おう\n• 友達にチャレンジを送信 — 相手が受けた瞬間に通知\n• チャレンジのプッシュ通知\n• サウンドとハプティクスを備えた新デザイン\n• 保護中のアプリをひと目で確認\n• 不具合の修正とパフォーマンス改善",
    "ko": "• 새로운 리더보드에서 경쟁하세요\n• 친구에게 챌린지 보내기 — 수락하는 순간 알림\n• 챌린지 푸시 알림\n• 사운드와 햅틱이 더해진 새 디자인\n• 보호 중인 앱을 한눈에\n• 버그 수정 및 성능 개선",
    "zh-Hans": "• 在全新排行榜上一较高下\n• 向好友发起挑战——对方接受时立即收到通知\n• 挑战推送通知\n• 全新设计，加入音效与触感反馈\n• 一眼查看受保护的应用\n• 修复问题并提升性能",
}


def main():
    app_id = asc.find_app_id()
    _, d = asc.get(f"/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=20")
    version_id = None
    for v in d.get("data", []):
        st = v["attributes"].get("appStoreState") or v["attributes"].get("state")
        if v["attributes"].get("versionString") == VERSION and st in EDITABLE_STATES:
            version_id = v["id"]
            break
    if not version_id:
        sys.exit(f"No editable {VERSION} found")

    _, d = asc.get(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    for loc in d.get("data", []):
        locale = loc["attributes"]["locale"]
        text = WHATS_NEW.get(locale)
        if not text:
            print(f"  ! no whatsNew for {locale}")
            continue
        st, resp = asc.patch(f"/appStoreVersionLocalizations/{loc['id']}", {
            "data": {"type": "appStoreVersionLocalizations", "id": loc["id"],
                     "attributes": {"whatsNew": text}}})
        print(f"  {'✓' if st == 200 else '✗'} {locale} ({st})")
        if st != 200:
            print("   ", json.dumps(resp)[:300])


if __name__ == "__main__":
    main()
