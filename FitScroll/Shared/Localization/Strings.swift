import Foundation

/// Centralized access to localized strings.
/// Values are looked up on each access so they respect live language changes.
/// Base language is English; falls back to English for unsupported device locales.
enum Strings {

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    enum App {
        static var name: String { localized("app.name") }
        static var tagline: String { localized("app.tagline") }
    }

    enum Onboarding {
        static var welcomeTitle: String { localized("onboarding.welcome.title") }
        static var welcomeSubtitle: String { localized("onboarding.welcome.subtitle") }
        static var step1Title: String { localized("onboarding.step1.title") }
        static var step1Description: String { localized("onboarding.step1.description") }
        static var step2Title: String { localized("onboarding.step2.title") }
        static var step2Description: String { localized("onboarding.step2.description") }
        static var step3Title: String { localized("onboarding.step3.title") }
        static var step3Description: String { localized("onboarding.step3.description") }
        static var getStarted: String { localized("onboarding.get_started") }
        static var next: String { localized("onboarding.next") }
        static var skip: String { localized("onboarding.skip") }
        static var back: String { localized("onboarding.back") }
        static var `continue`: String { localized("onboarding.continue") }
        static var finish: String { localized("onboarding.finish") }

        enum Hook {
            static var title: String { localized("onboarding.hook.title") }
            static var subtitle: String { localized("onboarding.hook.subtitle") }
        }

        enum Transform {
            static var title: String { localized("onboarding.transform.title") }
            static var before: String { localized("onboarding.transform.before") }
            static var after: String { localized("onboarding.transform.after") }
            static var before1: String { localized("onboarding.transform.before1") }
            static var before2: String { localized("onboarding.transform.before2") }
            static var before3: String { localized("onboarding.transform.before3") }
            static var after1: String { localized("onboarding.transform.after1") }
            static var after2: String { localized("onboarding.transform.after2") }
            static var after3: String { localized("onboarding.transform.after3") }
        }

        enum Privacy {
            static var title: String { localized("onboarding.privacy.title") }
            static var subtitle: String { localized("onboarding.privacy.subtitle") }
            static var screenTimeTitle: String { localized("onboarding.privacy.screen_time.title") }
            static var screenTimeBody: String { localized("onboarding.privacy.screen_time.body") }
            static var cameraTitle: String { localized("onboarding.privacy.camera.title") }
            static var cameraBody: String { localized("onboarding.privacy.camera.body") }
        }

        enum ScreenTimeStage {
            static var title: String { localized("onboarding.screen_time.title") }
            static var body: String { localized("onboarding.screen_time.body") }
            static var cta: String { localized("onboarding.screen_time.cta") }
            static var later: String { localized("onboarding.screen_time.later") }
        }

        enum CameraStage {
            static var title: String { localized("onboarding.camera.title") }
            static var body: String { localized("onboarding.camera.body") }
            static var cta: String { localized("onboarding.camera.cta") }
            static var later: String { localized("onboarding.camera.later") }
        }
    }

    enum Permissions {
        static var screenTimeTitle: String { localized("permissions.screen_time.title") }
        static var screenTimeDescription: String { localized("permissions.screen_time.description") }
        static var cameraTitle: String { localized("permissions.camera.title") }
        static var cameraDescription: String { localized("permissions.camera.description") }
        static var grantAccess: String { localized("permissions.grant_access") }
        static var openSettings: String { localized("permissions.open_settings") }
        static var title: String { localized("permissions.title") }
        static var subtitle: String { localized("permissions.subtitle") }
        static var `continue`: String { localized("permissions.continue") }
    }

    enum Dashboard {
        static var title: String { localized("dashboard.title") }
        static var activeLimits: String { localized("dashboard.active_limits") }
        static var todayEarned: String { localized("dashboard.today_earned") }
        static var lockedApps: String { localized("dashboard.locked_apps") }
        static var recentSessions: String { localized("dashboard.recent_sessions") }
        static var unlockNow: String { localized("dashboard.unlock_now") }
        static var noLimitsSet: String { localized("dashboard.no_limits_set") }
        static var noSessionsYet: String { localized("dashboard.no_sessions_yet") }
        static var statusUnrestrictedMessage: String { localized("dashboard.status.unrestricted_message") }
        static var statusRestrictedMessage: String { localized("dashboard.status.restricted_message") }
        static var statusTemporarilyUnlockedMessage: String { localized("dashboard.status.temporarily_unlocked_message") }
        static var heroEarnTime: String { localized("dashboard.hero.earn_time") }
        static var heroUnlockFreedom: String { localized("dashboard.hero.unlock_freedom") }
        static var heroSubtitle: String { localized("dashboard.hero.subtitle") }
        static var ringMinutesUnit: String { localized("dashboard.ring.minutes_unit") }
        static var ringEarnedToday: String { localized("dashboard.ring.earned_today") }
        static var chipDayStreak: String { localized("dashboard.chip.day_streak") }
        static var chipAppsProtected: String { localized("dashboard.chip.apps_protected") }
        static var chipLevelFormat: String { localized("dashboard.chip.level_format") }
        static var unlockScreenTime: String { localized("dashboard.unlock_screen_time") }
        static var seeAll: String { localized("dashboard.see_all") }
        static var repsFormat: String { localized("dashboard.reps_format") }
    }

    enum AppSelection {
        static var title: String { localized("app_selection.title") }
        static var subtitle: String { localized("app_selection.subtitle") }
        static var done: String { localized("app_selection.done") }
        static var noAppsSelected: String { localized("app_selection.no_apps_selected") }
        static var selectApps: String { localized("app_selection.select_apps") }
        static var apps: String { localized("app_selection.apps") }
        static var categories: String { localized("app_selection.categories") }
        static var lockedRightAway: String { localized("app_selection.locked_right_away") }
        static var lockedRightAwayBody: String { localized("app_selection.locked_right_away_body") }
    }

    enum Limits {
        static var title: String { localized("limits.title") }
        static var dailyLimit: String { localized("limits.daily_limit") }
        static var minutes: String { localized("limits.minutes") }
        static var save: String { localized("limits.save") }
        static var done: String { localized("limits.done") }
    }

    enum Unlock {
        static var title: String { localized("unlock.title") }
        static var subtitle: String { localized("unlock.subtitle") }
        static var minutesPerRep: String { localized("unlock.minutes_per_rep_format") }
        static var stableLabel: String { localized("unlock.stable_label") }
        static var experimentalLabel: String { localized("unlock.experimental_label") }
        static var startSession: String { localized("unlock.start_session") }
        static var sectionStable: String { localized("unlock.section_stable") }
        static var sectionExperimental: String { localized("unlock.section_experimental") }
        static var close: String { localized("unlock.close") }
        static var headerTitle: String { localized("unlock.header_title") }
        static var headerSubtitle: String { localized("unlock.header_subtitle") }
        static var chooseExercise: String { localized("unlock.choose_exercise") }
        static var repsFormat: String { localized("unlock.reps_format") }
        static var minutesFormat: String { localized("unlock.minutes_format") }
    }

    enum Workout {
        static var reps: String { localized("workout.reps") }
        static var minutes: String { localized("workout.minutes") }
        static var start: String { localized("workout.start") }
        static var pause: String { localized("workout.pause") }
        static var resume: String { localized("workout.resume") }
        static var finish: String { localized("workout.finish") }
        static var adjustPosition: String { localized("workout.adjust_position") }
        static var moveBetterLight: String { localized("workout.move_better_light") }
        static var greatForm: String { localized("workout.great_form") }
        static var moreRepsFormat: String { localized("workout.more_reps_format") }
        static var preparing: String { localized("workout.preparing") }
        static var simulatorMode: String { localized("workout.simulator_mode") }
        static var minutesEarnedFormat: String { localized("workout.minutes_earned_format") }
        static var openSettings: String { localized("workout.open_settings") }
        static var close: String { localized("workout.close") }
        static var quitTitle: String { localized("workout.quit_title") }
        static var quitDiscard: String { localized("workout.quit_discard") }
        static var keepGoing: String { localized("workout.keep_going") }
        static var quitMessage: String { localized("workout.quit_message") }
    }

    enum Summary {
        static var title: String { localized("summary.title") }
        static var totalReps: String { localized("summary.total_reps") }
        static var earnedMinutes: String { localized("summary.earned_minutes") }
        static var avgConfidence: String { localized("summary.avg_confidence") }
        static var duration: String { localized("summary.duration") }
        static var unlockMessage: String { localized("summary.unlock_message_format") }
        static var applyUnlock: String { localized("summary.apply_unlock") }
        static var backToDashboard: String { localized("summary.back_to_dashboard") }
    }

    enum History {
        static var title: String { localized("history.title") }
        static var noSessions: String { localized("history.no_sessions") }
        static var totalAllTime: String { localized("history.total_all_time") }
        static var sessions: String { localized("history.sessions") }
        static var reps: String { localized("history.reps") }
        static var minutes: String { localized("history.minutes") }
        static var sectionSessions: String { localized("history.section_sessions") }
        static var cancelled: String { localized("history.cancelled") }
        static var headerTitle: String { localized("history.header_title") }
        static var headerSubtitle: String { localized("history.header_subtitle") }
        static var recentWorkouts: String { localized("history.recent_workouts") }
        static var seeAll: String { localized("history.see_all") }
        static var noActivity: String { localized("history.no_activity") }
        static var repsFormat: String { localized("history.reps_format") }
    }

    enum Settings {
        static var title: String { localized("settings.title") }
        static var exerciseRewards: String { localized("settings.exercise_rewards") }
        static var minutesPerRepLabel: String { localized("settings.minutes_per_rep_label") }
        static var dailyMaxUnlock: String { localized("settings.daily_max_unlock") }
        static var defaultLimit: String { localized("settings.default_limit") }
        static var hapticFeedback: String { localized("settings.haptic_feedback") }
        static var debugMode: String { localized("settings.debug_mode") }
        static var debugSection: String { localized("settings.debug_section") }
        static var simulateReps: String { localized("settings.simulate_reps") }
        static var fakeUnlock: String { localized("settings.fake_unlock") }
        static var resetAll: String { localized("settings.reset_all") }
        static var about: String { localized("settings.about") }
        static var version: String { localized("settings.version") }
        static var privacyNote: String { localized("settings.privacy_note") }
        static var preferences: String { localized("settings.preferences") }
        static var characterStyle: String { localized("settings.character_style") }
        static var resetConfirmTitle: String { localized("settings.reset_confirm_title") }
        static var resetConfirmMessage: String { localized("settings.reset_confirm_message") }
        static var resetConfirmButton: String { localized("settings.reset_confirm_button") }
        static var headerTitle: String { localized("settings.header_title") }
        static var manageSubscription: String { localized("settings.manage_subscription") }
        static var headerSubtitle: String { localized("settings.header_subtitle") }
        static var minutesPerRepFormat: String { localized("settings.minutes_per_rep_format") }
        static var minutesValueFormat: String { localized("settings.minutes_value_format") }
        static var rateApp: String { localized("settings.rate_app") }
    }

    enum Journey {
        static var title: String { localized("journey.title") }
        static var headerTitle: String { localized("journey.header_title") }
        static var headerSubtitle: String { localized("journey.header_subtitle") }
        static var statDayStreak: String { localized("journey.stat.day_streak") }
        static var statXP: String { localized("journey.stat.xp") }
        static var statLevel: String { localized("journey.stat.level") }
        static var xpProgressFormat: String { localized("journey.xp_progress_format") }
        static var milestones: String { localized("journey.milestones") }
        static var stateCompleted: String { localized("journey.state.completed") }
        static var stateInProgressFormat: String { localized("journey.state.in_progress_format") }
        static var stateLocked: String { localized("journey.state.locked") }
        static var bossLevel: String { localized("journey.boss_level") }
        static var rewardXPFormat: String { localized("journey.reward_xp_format") }
        static var rewardMinutesFormat: String { localized("journey.reward_minutes_format") }
        static var start: String { localized("journey.start") }
        static var close: String { localized("journey.close") }
        static var passiveExplainer: String { localized("journey.passive_explainer") }
        static var goToWorkouts: String { localized("journey.go_to_workouts") }
        static var bossDefeated: String { localized("journey.boss_defeated") }
        static var levelComplete: String { localized("journey.level_complete") }
        static var rewardXPShortFormat: String { localized("journey.reward_xp_short_format") }
        static var rewardMinutesShortFormat: String { localized("journey.reward_minutes_short_format") }
        static var rewardXPCaption: String { localized("journey.reward_xp_caption") }
        static var rewardMinutesCaption: String { localized("journey.reward_minutes_caption") }
        static var newBadge: String { localized("journey.new_badge") }
        static var `continue`: String { localized("journey.continue") }
        static var badges: String { localized("journey.badges") }
        static var done: String { localized("journey.done") }
    }

    enum Paywall {
        static var title: String { localized("paywall.title") }
        static var subtitle: String { localized("paywall.subtitle") }
        static var valueProp1: String { localized("paywall.value_prop_1") }
        static var valueProp2: String { localized("paywall.value_prop_2") }
        static var valueProp3: String { localized("paywall.value_prop_3") }
        static var valueProp4: String { localized("paywall.value_prop_4") }
        static var ctaFreeTrial: String { localized("paywall.cta_free_trial") }
        static var ctaBuyLifetime: String { localized("paywall.cta_buy_lifetime") }
        static var ctaSubscribe: String { localized("paywall.cta_subscribe") }
        static var restorePurchases: String { localized("paywall.restore_purchases") }
        static var termsOfUse: String { localized("paywall.terms_of_use") }
        static var privacyPolicy: String { localized("paywall.privacy_policy") }
        static var legalFooter: String { localized("paywall.legal_footer") }
        static var bestValue: String { localized("paywall.best_value") }
        static var planYearly: String { localized("paywall.plan.yearly") }
        static var planMonthly: String { localized("paywall.plan.monthly") }
        static var planLifetime: String { localized("paywall.plan.lifetime") }
        static var planYearlySubtitle: String { localized("paywall.plan.yearly_subtitle") }
        static var planMonthlySubtitle: String { localized("paywall.plan.monthly_subtitle") }
        static var planLifetimeSubtitle: String { localized("paywall.plan.lifetime_subtitle") }
        static var pricePerMonthApproxFormat: String { localized("paywall.price.per_month_approx_format") }
        static var pricePerMonth: String { localized("paywall.price.per_month") }
        static var priceOneTime: String { localized("paywall.price.one_time") }
    }

    enum WinBack {
        static var title: String { localized("winback.title") }
        static var subtitle: String { localized("winback.subtitle") }
        static var badge: String { localized("winback.badge") }
        static var ctaClaim: String { localized("winback.cta_claim") }
        static var seeAllPlans: String { localized("winback.see_all_plans") }
        static var firstMonthFormat: String { localized("winback.first_month_format") }
        static var firstYearFormat: String { localized("winback.first_year_format") }
        static var thenPriceFormat: String { localized("winback.then_price_format") }
        static var cancelAnytime: String { localized("winback.cancel_anytime") }
    }

    enum Notifications {
        static var oneMinuteWarningTitle: String { localized("notifications.one_minute_warning.title") }
        static var oneMinuteWarningBodySingular: String { localized("notifications.one_minute_warning.body_singular") }
        static var oneMinuteWarningBodyPluralFormat: String { localized("notifications.one_minute_warning.body_plural_format") }
        static var lockedAgainTitleSingular: String { localized("notifications.locked_again.title_singular") }
        static var lockedAgainTitlePluralFormat: String { localized("notifications.locked_again.title_plural_format") }
        static var lockedAgainBodySingular: String { localized("notifications.locked_again.body_singular") }
        static var lockedAgainBodyPluralFormat: String { localized("notifications.locked_again.body_plural_format") }
    }

    enum Errors {
        static var cameraPermissionDenied: String { localized("errors.camera_permission_denied") }
        static var cameraRecovery: String { localized("errors.camera_recovery") }
        static var screenTimePermissionDenied: String { localized("errors.screen_time_permission_denied") }
        static var screenTimeRecovery: String { localized("errors.screen_time_recovery") }
        static var noAppsSelected: String { localized("errors.no_apps_selected") }
        static var poseNotDetected: String { localized("errors.pose_not_detected") }
        static var poseRecovery: String { localized("errors.pose_recovery") }
        static var lowLight: String { localized("errors.low_light") }
        static var lightRecovery: String { localized("errors.light_recovery") }
        static var outOfFrame: String { localized("errors.out_of_frame") }
        static var incompleteMotion: String { localized("errors.incomplete_motion") }
        static var genericError: String { localized("errors.generic") }
        static var tryAgain: String { localized("errors.try_again") }
        static var cameraDeniedFull: String { localized("errors.camera_denied_full") }
        static var cameraDeniedRestricted: String { localized("errors.camera_denied_restricted") }
    }
}
