"use client";

import { useEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

// =============================================================================
// Constants — canvas dimensions, export sizes, frame ratios
// =============================================================================

const W = 1320; // iPhone 6.9" — design canvas width (largest required)
const H = 2868;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

// iPhone mockup pre-measurements (from skill's mockup.png — 1022×2082)
const MK_W = 1022;
const MK_H = 2082;
const MK_RATIO = MK_W / MK_H;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

// Width formula: fraction of canvas width used by the phone
function phoneW(cW: number, cH: number, clamp = 0.84) {
  return Math.min(clamp, 0.72 * (cH / cW) * MK_RATIO);
}

// =============================================================================
// Theme — FitScroll brand palette
// =============================================================================

const FS = {
  orange: "#EF4723",
  orangeDark: "#C62D0F",
  amber: "#F5A623",
  navyDeep: "#060922",
  navy: "#0E1535",
  navyLight: "#1A2554",
  cyan: "#00E5D1",
  white: "#FFFFFF",
  cream: "#FEF7EF",
  goldLight: "#FFD65C",
  purple: "#5B2A86",
};

// =============================================================================
// Image preloading — convert all assets to base64 data URIs so html-to-image
// captures them deterministically.
// =============================================================================

const IMAGE_PATHS = [
  "/mockup.png",
  "/app-icon.png",
  "/pushup_up.png",
  "/pushup_down.png",
  "/squat_up.png",
  "/squat_down.png",
  "/screenshots/en/move-to-unlock.png",
  "/screenshots/en/pushup-sample.png",
  "/screenshots/en/pose-detection.png",
  "/screenshots/en/rep-counter.png",
  "/screenshots/en/history.png",
];

const imageCache: Record<string, string> = {};

async function preloadAllImages() {
  await Promise.all(
    IMAGE_PATHS.map(async (path) => {
      try {
        const resp = await fetch(path);
        const blob = await resp.blob();
        const dataUrl = await new Promise<string>((resolve) => {
          const reader = new FileReader();
          reader.onloadend = () => resolve(reader.result as string);
          reader.readAsDataURL(blob);
        });
        imageCache[path] = dataUrl;
      } catch (e) {
        console.warn("preload failed:", path, e);
      }
    }),
  );
}

function img(path: string): string {
  return imageCache[path] || path;
}

// =============================================================================
// Device frame — iPhone (PNG mockup)
// =============================================================================

function Phone({
  src,
  alt,
  style,
}: {
  src?: string;
  alt?: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}) {
  return (
    <div
      style={{
        position: "relative",
        aspectRatio: `${MK_W}/${MK_H}`,
        ...style,
      }}
    >
      <img
        src={img("/mockup.png")}
        alt=""
        style={{ display: "block", width: "100%", height: "100%" }}
        draggable={false}
      />
      <div
        style={{
          position: "absolute",
          zIndex: 10,
          overflow: "hidden",
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        {src ? (
          <img
            src={src}
            alt={alt || ""}
            style={{
              display: "block",
              width: "100%",
              height: "100%",
              objectFit: "cover",
              objectPosition: "top",
            }}
            draggable={false}
          />
        ) : null}
      </div>
    </div>
  );
}

/**
 * Composed phone — renders custom React content inside the phone's screen
 * area. Used for slides where we don't have a real device capture.
 */
function PhoneComposed({
  style,
  children,
}: {
  style?: React.CSSProperties;
  children: React.ReactNode;
}) {
  return (
    <div
      style={{
        position: "relative",
        aspectRatio: `${MK_W}/${MK_H}`,
        ...style,
      }}
    >
      <img
        src={img("/mockup.png")}
        alt=""
        style={{ display: "block", width: "100%", height: "100%" }}
        draggable={false}
      />
      <div
        style={{
          position: "absolute",
          zIndex: 10,
          overflow: "hidden",
          left: `${SC_L}%`,
          top: `${SC_T}%`,
          width: `${SC_W}%`,
          height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`,
        }}
      >
        {children}
      </div>
    </div>
  );
}

// =============================================================================
// Caption — the headline block above/around the phone
// =============================================================================

function Caption({
  cW,
  label,
  headline,
  color = FS.white,
  labelColor = FS.orange,
  style,
}: {
  cW: number;
  label?: string;
  headline: React.ReactNode;
  color?: string;
  labelColor?: string;
  style?: React.CSSProperties;
}) {
  return (
    <div
      style={{
        position: "absolute",
        top: "8%",
        left: "6%",
        right: "6%",
        textAlign: "center",
        zIndex: 5,
        ...style,
      }}
    >
      {label && (
        <div
          style={{
            fontSize: cW * 0.026,
            fontWeight: 700,
            letterSpacing: cW * 0.002,
            color: labelColor,
            textTransform: "uppercase",
            marginBottom: cW * 0.018,
          }}
        >
          {label}
        </div>
      )}
      <div
        style={{
          fontSize: cW * 0.095,
          fontWeight: 800,
          lineHeight: 0.95,
          color,
          letterSpacing: -cW * 0.0016,
        }}
      >
        {headline}
      </div>
    </div>
  );
}

// =============================================================================
// Decorative elements — ambient glows, blobs
// =============================================================================

function OrangeGlow({ cW, cH }: { cW: number; cH: number }) {
  return (
    <>
      <div
        style={{
          position: "absolute",
          top: "-10%",
          left: "-20%",
          width: cW * 0.8,
          height: cW * 0.8,
          borderRadius: "50%",
          background: FS.orange,
          filter: "blur(140px)",
          opacity: 0.65,
          pointerEvents: "none",
        }}
      />
      <div
        style={{
          position: "absolute",
          bottom: "10%",
          right: "-15%",
          width: cW * 0.75,
          height: cW * 0.75,
          borderRadius: "50%",
          background: FS.amber,
          filter: "blur(140px)",
          opacity: 0.4,
          pointerEvents: "none",
        }}
      />
    </>
  );
}

function StarField({ cW, cH }: { cW: number; cH: number }) {
  // Deterministic dots (no randomness so export matches preview)
  const dots = [];
  const seed = [0.12, 0.83, 0.42, 0.69, 0.21, 0.55, 0.91, 0.33, 0.76, 0.08, 0.47, 0.62, 0.19, 0.87, 0.38];
  for (let i = 0; i < 30; i++) {
    const x = seed[(i * 3) % seed.length] * 100;
    const y = seed[(i * 5 + 1) % seed.length] * 100;
    const size = 2 + (seed[(i * 7 + 2) % seed.length] * 3);
    dots.push(
      <div
        key={i}
        style={{
          position: "absolute",
          left: `${x}%`,
          top: `${y}%`,
          width: size,
          height: size,
          borderRadius: "50%",
          background: FS.white,
          opacity: 0.45,
        }}
      />,
    );
  }
  return <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>{dots}</div>;
}

// =============================================================================
// Slide components — 6 slides for FitScroll
// =============================================================================

type SlideProps = { cW: number; cH: number };
type SlideDef = { id: string; component: (p: SlideProps) => React.ReactElement };

// -----------------------------------------------------------------------------
// Slide 1 — Hero: "Move to unlock."
// -----------------------------------------------------------------------------

const slide1: SlideDef = {
  id: "hero",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          // Dark navy at the top (behind the headline) fading into warm
          // orange at the bottom (behind the phone). Keeps white text readable.
          background: `linear-gradient(180deg, ${FS.navyDeep} 0%, ${FS.navy} 30%, ${FS.orangeDark} 78%, ${FS.orange} 100%)`,
          overflow: "hidden",
        }}
      >
        <StarField cW={cW} cH={cH} />
        {/* Warm glow hugging the bottom where the phone sits */}
        <div
          style={{
            position: "absolute",
            bottom: "-20%",
            left: "50%",
            transform: "translateX(-50%)",
            width: cW * 1.3,
            height: cW * 0.9,
            borderRadius: "50%",
            background: FS.amber,
            filter: "blur(180px)",
            opacity: 0.55,
          }}
        />
        {/* Strong dark veil behind the text for guaranteed contrast */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            height: "45%",
            background: `linear-gradient(180deg, rgba(0,0,0,0.75) 0%, rgba(0,0,0,0.4) 55%, rgba(0,0,0,0) 100%)`,
            pointerEvents: "none",
          }}
        />

        {/* FitScroll label */}
        <div
          style={{
            position: "absolute",
            top: "6%",
            left: 0,
            right: 0,
            textAlign: "center",
            zIndex: 6,
          }}
        >
          <span
            style={{
              fontSize: cW * 0.034,
              fontWeight: 800,
              letterSpacing: cW * 0.003,
              color: FS.amber,
              textTransform: "uppercase",
              textShadow: "0 2px 14px rgba(0,0,0,0.8)",
            }}
          >
            FITSCROLL
          </span>
        </div>

        {/* Huge headline */}
        <div
          style={{
            position: "absolute",
            top: "11%",
            left: "4%",
            right: "4%",
            textAlign: "center",
            zIndex: 6,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.14,
              fontWeight: 900,
              lineHeight: 0.92,
              color: FS.white,
              letterSpacing: -cW * 0.003,
              textShadow:
                "0 6px 28px rgba(0,0,0,0.85), 0 2px 8px rgba(0,0,0,0.9)",
            }}
          >
            Move to
            <br />
            unlock.
          </div>
        </div>

        {/* Subtitle */}
        <div
          style={{
            position: "absolute",
            top: "30%",
            left: "50%",
            transform: "translateX(-50%)",
            textAlign: "center",
            width: "82%",
            zIndex: 6,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.038,
              color: FS.white,
              lineHeight: 1.35,
              fontWeight: 600,
              textShadow: "0 3px 16px rgba(0,0,0,0.85)",
            }}
          >
            Turn doomscrolling into push-ups.
            <br />
            Every rep earns minutes back.
          </div>
        </div>

        <Phone
          src={img("/screenshots/en/move-to-unlock.png")}
          alt="Onboarding"
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: `translateX(-50%) translateY(12%)`,
            width: `${fw}%`,
          }}
        />
      </div>
    );
  },
};

// -----------------------------------------------------------------------------
// Slide 2 — Differentiator: camera counts reps
// -----------------------------------------------------------------------------

const slide2: SlideDef = {
  id: "camera-counts-reps",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `linear-gradient(180deg, ${FS.navyDeep} 0%, ${FS.navy} 70%, ${FS.navyLight} 100%)`,
          overflow: "hidden",
        }}
      >
        <StarField cW={cW} cH={cH} />
        <div
          style={{
            position: "absolute",
            top: "30%",
            left: "50%",
            transform: "translate(-50%, -50%)",
            width: cW * 0.85,
            height: cW * 0.85,
            borderRadius: "50%",
            background: FS.cyan,
            filter: "blur(180px)",
            opacity: 0.28,
          }}
        />

        <Caption
          cW={cW}
          label="LIVE POSE DETECTION"
          labelColor={FS.cyan}
          headline={
            <>
              Your camera
              <br />
              counts every rep.
            </>
          }
        />

        <div
          style={{
            position: "absolute",
            top: "28%",
            left: "50%",
            transform: "translateX(-50%)",
            textAlign: "center",
            width: "80%",
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.028,
              color: "rgba(255,255,255,0.7)",
              lineHeight: 1.4,
              fontWeight: 500,
            }}
          >
            On-device AI. No videos recorded.
            <br />
            Nothing ever leaves your phone.
          </div>
        </div>

        <Phone
          src={img("/screenshots/en/pushup-sample.png")}
          alt="Pose detection"
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(12%)",
            width: `${fw}%`,
          }}
        />
      </div>
    );
  },
};

// -----------------------------------------------------------------------------
// Slide 3 — Lock the apps that steal your time
// -----------------------------------------------------------------------------

const slide3: SlideDef = {
  id: "lock-apps",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `linear-gradient(165deg, #150308 0%, #4B0B0B 40%, ${FS.orange} 100%)`,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            bottom: "0",
            left: "-10%",
            width: cW * 1.2,
            height: cW * 0.7,
            borderRadius: "50%",
            background: FS.orange,
            filter: "blur(180px)",
            opacity: 0.6,
          }}
        />

        <Caption
          cW={cW}
          label="SCREEN TIME LOCK"
          labelColor={FS.amber}
          headline={
            <>
              Lock the apps
              <br />
              that steal hours.
            </>
          }
        />

        <div
          style={{
            position: "absolute",
            top: "28%",
            left: "50%",
            transform: "translateX(-50%)",
            textAlign: "center",
            width: "85%",
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.03,
              color: "rgba(255,255,255,0.75)",
              lineHeight: 1.4,
              fontWeight: 500,
            }}
          >
            Instagram. TikTok. YouTube. X.
            <br />
            Whatever keeps you scrolling.
          </div>
        </div>

        <PhoneComposed
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(12%)",
            width: `${fw}%`,
          }}
        >
          <ShieldScreenMock cW={cW} />
        </PhoneComposed>
      </div>
    );
  },
};

// -----------------------------------------------------------------------------
// Slide 4 — Earn back time: every rep counts
// -----------------------------------------------------------------------------

const slide4: SlideDef = {
  id: "earn-minutes",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `linear-gradient(180deg, ${FS.navyDeep} 0%, ${FS.navy} 55%, ${FS.orangeDark} 100%)`,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: "22%",
            left: "50%",
            transform: "translate(-50%, -50%)",
            width: cW * 0.95,
            height: cW * 0.95,
            borderRadius: "50%",
            background: FS.amber,
            filter: "blur(170px)",
            opacity: 0.45,
          }}
        />
        <StarField cW={cW} cH={cH} />

        <Caption
          cW={cW}
          label="COIN THE TIME"
          labelColor={FS.amber}
          headline={
            <>
              Every rep earns
              <br />
              minutes back.
            </>
          }
        />

        <div
          style={{
            position: "absolute",
            top: "29%",
            left: "50%",
            transform: "translateX(-50%)",
            textAlign: "center",
            width: "78%",
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.03,
              color: "rgba(255,255,255,0.75)",
              lineHeight: 1.4,
              fontWeight: 500,
            }}
          >
            Push-up or squat your way back
            <br />
            to your feed. Your choice, your grind.
          </div>
        </div>

        <Phone
          src={img("/screenshots/en/pose-detection.png")}
          alt="Squat up"
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(12%)",
            width: `${fw}%`,
          }}
        />
      </div>
    );
  },
};

// -----------------------------------------------------------------------------
// Slide 4b — Squat DOWN: the descent
// -----------------------------------------------------------------------------

const slide4b: SlideDef = {
  id: "squat-down",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `linear-gradient(180deg, ${FS.orangeDark} 0%, ${FS.navy} 55%, ${FS.navyDeep} 100%)`,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: "22%",
            left: "50%",
            transform: "translate(-50%, -50%)",
            width: cW * 0.95,
            height: cW * 0.95,
            borderRadius: "50%",
            background: FS.orange,
            filter: "blur(170px)",
            opacity: 0.45,
          }}
        />
        <StarField cW={cW} cH={cH} />

        <Caption
          cW={cW}
          label="GO LOWER"
          labelColor={FS.amber}
          headline={
            <>
              Push deeper,
              <br />
              earn faster.
            </>
          }
        />

        <div
          style={{
            position: "absolute",
            top: "29%",
            left: "50%",
            transform: "translateX(-50%)",
            textAlign: "center",
            width: "80%",
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.03,
              color: "rgba(255,255,255,0.75)",
              lineHeight: 1.4,
              fontWeight: 500,
            }}
          >
            Full range counts.
            <br />
            Half reps don't.
          </div>
        </div>

        <Phone
          src={img("/screenshots/en/rep-counter.png")}
          alt="Squat down"
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(12%)",
            width: `${fw}%`,
          }}
        />
      </div>
    );
  },
};

// -----------------------------------------------------------------------------
// Slide 5 — Analytics: track your streak
// -----------------------------------------------------------------------------

const slide5: SlideDef = {
  id: "analytics",
  component: ({ cW, cH }) => {
    const fw = phoneW(cW, cH) * 100;
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `linear-gradient(175deg, ${FS.navyDeep} 0%, ${FS.navyLight} 50%, ${FS.purple} 100%)`,
          overflow: "hidden",
        }}
      >
        <StarField cW={cW} cH={cH} />
        <div
          style={{
            position: "absolute",
            bottom: "30%",
            right: "-20%",
            width: cW * 0.85,
            height: cW * 0.85,
            borderRadius: "50%",
            background: FS.cyan,
            filter: "blur(180px)",
            opacity: 0.35,
          }}
        />

        <Caption
          cW={cW}
          label="TRACK THE STREAK"
          labelColor={FS.cyan}
          headline={
            <>
              Watch the
              <br />
              streak grow.
            </>
          }
        />

        <div
          style={{
            position: "absolute",
            top: "28%",
            left: "50%",
            transform: "translateX(-50%)",
            textAlign: "center",
            width: "80%",
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.03,
              color: "rgba(255,255,255,0.75)",
              lineHeight: 1.4,
              fontWeight: 500,
            }}
          >
            Your reps and minutes, day by day.
            <br />
            See the loop you're breaking.
          </div>
        </div>

        <Phone
          src={img("/screenshots/en/history.png")}
          alt="Workout history"
          style={{
            position: "absolute",
            bottom: 0,
            left: "50%",
            transform: "translateX(-50%) translateY(12%)",
            width: `${fw}%`,
          }}
        />
      </div>
    );
  },
};

// -----------------------------------------------------------------------------
// Slide 6 — More features / trust signal
// -----------------------------------------------------------------------------

const slide6: SlideDef = {
  id: "more",
  component: ({ cW, cH }) => {
    const pills = [
      "On-device pose detection",
      "Live skeleton overlay",
      "Earn screen time",
      "Block distracting apps",
      "Daily usage limits",
      "History & analytics",
      "Smart unlock alerts",
      "100% private",
    ];
    return (
      <div
        style={{
          width: "100%",
          height: "100%",
          position: "relative",
          background: `radial-gradient(ellipse at 50% 20%, ${FS.navyLight} 0%, ${FS.navyDeep} 70%)`,
          overflow: "hidden",
        }}
      >
        <StarField cW={cW} cH={cH} />
        <OrangeGlow cW={cW} cH={cH} />

        {/* Big centered app icon — the visual anchor of the final slide */}
        <div
          style={{
            position: "absolute",
            top: "14%",
            left: 0,
            right: 0,
            display: "flex",
            justifyContent: "center",
            zIndex: 5,
          }}
        >
          <img
            src={img("/app-icon.png")}
            alt=""
            style={{
              width: cW * 0.42,
              height: cW * 0.42,
              borderRadius: cW * 0.1,
              boxShadow: `0 ${cW * 0.03}px ${cW * 0.12}px ${FS.orange}88, 0 0 ${cW * 0.2}px ${FS.amber}55`,
            }}
            draggable={false}
          />
        </div>

        {/* Headline + subtitle below the icon */}
        <div
          style={{
            position: "absolute",
            top: "42%",
            left: 0,
            right: 0,
            textAlign: "center",
            zIndex: 5,
          }}
        >
          <div
            style={{
              fontSize: cW * 0.105,
              fontWeight: 800,
              color: FS.white,
              lineHeight: 0.95,
              letterSpacing: -cW * 0.0018,
            }}
          >
            Break the
            <br />
            dopamine loop.
          </div>
          <div
            style={{
              marginTop: cW * 0.035,
              fontSize: cW * 0.034,
              color: "rgba(255,255,255,0.82)",
              fontWeight: 500,
              lineHeight: 1.4,
            }}
          >
            Try free for 7 days.
            <br />
            Take your time back.
          </div>
        </div>

        <div
          style={{
            position: "absolute",
            bottom: "10%",
            left: "8%",
            right: "8%",
            display: "flex",
            flexWrap: "wrap",
            gap: cW * 0.02,
            justifyContent: "center",
          }}
        >
          {pills.map((p) => (
            <div
              key={p}
              style={{
                padding: `${cW * 0.022}px ${cW * 0.04}px`,
                borderRadius: cW * 0.05,
                background: "rgba(255,255,255,0.08)",
                border: "1px solid rgba(255,255,255,0.18)",
                color: FS.white,
                fontSize: cW * 0.028,
                fontWeight: 600,
                backdropFilter: "blur(12px)",
              }}
            >
              {p}
            </div>
          ))}
        </div>

        {/* Bottom character as glow */}
        <img
          src={img("/pushup_up.png")}
          alt=""
          style={{
            position: "absolute",
            bottom: "-4%",
            right: "-6%",
            width: cW * 0.28,
            opacity: 0.25,
            filter: "blur(1px)",
          }}
          draggable={false}
        />
      </div>
    );
  },
};

const SLIDES: SlideDef[] = [slide1, slide2, slide3, slide4, slide4b, slide5, slide6];

// =============================================================================
// Composed in-phone mocks — fake app screens rendered with React
// =============================================================================

/** Mock Camera Workout screen with character + rep pill + cyan skeleton overlay. */
function WorkoutScreenMock({ cW, kind }: { cW: number; kind: "pushup" | "squat" }) {
  const char = kind === "pushup" ? "/pushup_down.png" : "/squat_down.png";
  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        background: `radial-gradient(ellipse at 50% 50%, #12183a 0%, #04061a 100%)`,
        overflow: "hidden",
      }}
    >
      {/* Ambient cyan glow */}
      <div
        style={{
          position: "absolute",
          top: "30%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          width: "120%",
          aspectRatio: "1",
          borderRadius: "50%",
          background: FS.cyan,
          filter: "blur(120px)",
          opacity: 0.25,
        }}
      />

      {/* Character */}
      <img
        src={img(char)}
        alt=""
        style={{
          position: "absolute",
          top: "18%",
          left: "50%",
          transform: "translateX(-50%)",
          width: "95%",
        }}
        draggable={false}
      />

      {/* Pose skeleton overlay SVG — on top of the character */}
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="none"
        style={{
          position: "absolute",
          top: "18%",
          left: "20%",
          width: "60%",
          height: "50%",
          overflow: "visible",
        }}
      >
        <g stroke={FS.cyan} strokeWidth="1.2" strokeLinecap="round" fill="none">
          {/* shoulders */}
          <line x1="30" y1="40" x2="70" y2="40" />
          {/* left arm */}
          <line x1="30" y1="40" x2="15" y2="72" />
          <line x1="15" y1="72" x2="22" y2="98" />
          {/* right arm */}
          <line x1="70" y1="40" x2="85" y2="72" />
          <line x1="85" y1="72" x2="78" y2="98" />
          {/* torso */}
          <line x1="30" y1="40" x2="38" y2="95" />
          <line x1="70" y1="40" x2="62" y2="95" />
        </g>
        <g fill="#fff" stroke={FS.cyan} strokeWidth="1">
          <circle cx="30" cy="40" r="2" />
          <circle cx="70" cy="40" r="2" />
          <circle cx="15" cy="72" r="1.8" />
          <circle cx="85" cy="72" r="1.8" />
          <circle cx="22" cy="98" r="1.6" />
          <circle cx="78" cy="98" r="1.6" />
          <circle cx="38" cy="95" r="1.6" />
          <circle cx="62" cy="95" r="1.6" />
        </g>
      </svg>

      {/* Top-left rep character pill — styled like in the real app */}
      <div
        style={{
          position: "absolute",
          top: "5%",
          left: "5%",
          padding: "3%",
          background: "rgba(255,255,255,0.1)",
          borderRadius: "5%",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.15)",
          width: "22%",
          aspectRatio: "90/140",
        }}
      >
        <img
          src={img("/pushup_down.png")}
          alt=""
          style={{ width: "100%", height: "100%", objectFit: "contain" }}
          draggable={false}
        />
      </div>

      {/* Giant rep counter circle */}
      <div
        style={{
          position: "absolute",
          bottom: "12%",
          left: "50%",
          transform: "translateX(-50%)",
          width: "32%",
          aspectRatio: "1",
          borderRadius: "50%",
          background: `linear-gradient(135deg, ${FS.amber}, ${FS.orange})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 0 80px ${FS.amber}99, inset 0 0 0 3px rgba(255,255,255,0.45)`,
        }}
      >
        <div
          style={{
            fontSize: cW * 0.12,
            fontWeight: 900,
            color: FS.white,
            fontFamily: "system-ui",
          }}
        >
          8
        </div>
      </div>
    </div>
  );
}

/** Mock shield (app locked) screen. */
function ShieldScreenMock({ cW }: { cW: number }) {
  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        background: `radial-gradient(ellipse at 50% 40%, #18213e 0%, #050819 100%)`,
        padding: "12% 8%",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "space-between",
      }}
    >
      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
        <img
          src={img("/app-icon.png")}
          alt=""
          style={{
            width: "28%",
            borderRadius: "20%",
            marginBottom: "6%",
            boxShadow: `0 8px 40px ${FS.orange}88`,
          }}
          draggable={false}
        />
        <div
          style={{
            fontSize: cW * 0.05,
            fontWeight: 800,
            color: FS.white,
            textAlign: "center",
            marginBottom: "2%",
          }}
        >
          Time to Move 💪
        </div>
        <div
          style={{
            fontSize: cW * 0.026,
            color: "rgba(255,255,255,0.7)",
            textAlign: "center",
            lineHeight: 1.4,
          }}
        >
          This app is locked.
          <br />
          Open FitScroll and finish an
          <br />
          exercise to earn screen time.
        </div>
      </div>

      <div
        style={{
          width: "100%",
          padding: "5%",
          background: `linear-gradient(135deg, #1a70ff, #0055d5)`,
          borderRadius: cW * 0.03,
          textAlign: "center",
          fontSize: cW * 0.032,
          fontWeight: 700,
          color: FS.white,
          marginBottom: "4%",
        }}
      >
        Close
      </div>
    </div>
  );
}

/** Mock circular rep counter mid-workout. */
function RepCounterMock({ cW }: { cW: number }) {
  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        background: `radial-gradient(ellipse at 50% 60%, #1a0e22 0%, #050413 100%)`,
        overflow: "hidden",
      }}
    >
      {/* Ambient golden glow */}
      <div
        style={{
          position: "absolute",
          bottom: "22%",
          left: "50%",
          transform: "translate(-50%, 0)",
          width: "120%",
          aspectRatio: "1",
          borderRadius: "50%",
          background: FS.amber,
          filter: "blur(150px)",
          opacity: 0.35,
        }}
      />

      {/* Character (squat up / standing) */}
      <img
        src={img("/pushup_up.png")}
        alt=""
        style={{
          position: "absolute",
          top: "8%",
          left: "50%",
          transform: "translateX(-50%)",
          width: "75%",
          opacity: 0.8,
        }}
        draggable={false}
      />

      {/* Top pill: rep character card */}
      <div
        style={{
          position: "absolute",
          top: "5%",
          left: "5%",
          padding: "3%",
          background: "rgba(255,255,255,0.12)",
          borderRadius: "8%",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.15)",
          width: "22%",
          aspectRatio: "90/140",
        }}
      >
        <img
          src={img("/pushup_up.png")}
          alt=""
          style={{ width: "100%", height: "100%", objectFit: "contain" }}
          draggable={false}
        />
      </div>

      {/* Giant circular counter — the hero element for this slide */}
      <div
        style={{
          position: "absolute",
          bottom: "22%",
          left: "50%",
          transform: "translateX(-50%)",
          width: "42%",
          aspectRatio: "1",
          borderRadius: "50%",
          background: `linear-gradient(135deg, ${FS.goldLight}, ${FS.orange})`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 0 120px ${FS.amber}cc, inset 0 0 0 4px rgba(255,255,255,0.5)`,
        }}
      >
        <div
          style={{
            fontSize: cW * 0.18,
            fontWeight: 900,
            color: FS.white,
            fontFamily: "system-ui",
            lineHeight: 1,
          }}
        >
          12
        </div>
      </div>

      {/* Sparkle / coin icons around */}
      <div
        style={{
          position: "absolute",
          bottom: "56%",
          right: "18%",
          fontSize: cW * 0.045,
        }}
      >
        ✨
      </div>
      <div
        style={{
          position: "absolute",
          bottom: "42%",
          left: "12%",
          fontSize: cW * 0.05,
        }}
      >
        🪙
      </div>
    </div>
  );
}

/** Mock workout history screen with chart. */
function HistoryScreenMock({ cW }: { cW: number }) {
  const values = [20, 35, 12, 48, 25, 60, 45]; // last 7 days
  const days = ["M", "T", "W", "T", "F", "S", "S"];
  const maxV = Math.max(...values);
  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        height: "100%",
        background: "#0A0F22",
        padding: "10% 6%",
        display: "flex",
        flexDirection: "column",
      }}
    >
      <div
        style={{
          fontSize: cW * 0.04,
          fontWeight: 800,
          color: FS.white,
          marginBottom: "3%",
        }}
      >
        Workout History
      </div>

      {/* Stat cards row */}
      <div style={{ display: "flex", gap: "3%", marginBottom: "6%" }}>
        {[
          { label: "Sessions", value: "24", icon: "🔥", color: FS.amber },
          { label: "Reps", value: "245", icon: "🏋️", color: FS.cyan },
          { label: "Minutes", value: "187m", icon: "⏱", color: "#5EF276" },
        ].map((s) => (
          <div
            key={s.label}
            style={{
              flex: 1,
              padding: "5% 3%",
              background: "rgba(255,255,255,0.06)",
              borderRadius: "8%",
              textAlign: "center",
              border: "1px solid rgba(255,255,255,0.1)",
            }}
          >
            <div style={{ fontSize: cW * 0.04, marginBottom: "5%" }}>{s.icon}</div>
            <div style={{ fontSize: cW * 0.04, color: FS.white, fontWeight: 800 }}>{s.value}</div>
            <div style={{ fontSize: cW * 0.022, color: "rgba(255,255,255,0.6)", marginTop: "3%" }}>{s.label}</div>
          </div>
        ))}
      </div>

      <div
        style={{
          fontSize: cW * 0.028,
          fontWeight: 600,
          color: "rgba(255,255,255,0.6)",
          marginBottom: "3%",
          textTransform: "uppercase",
          letterSpacing: cW * 0.001,
        }}
      >
        Activity · Last 7 Days
      </div>

      <div
        style={{
          flex: 1,
          padding: "5%",
          background: "rgba(255,255,255,0.05)",
          borderRadius: "5%",
          border: "1px solid rgba(255,255,255,0.08)",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "flex-end",
            justifyContent: "space-between",
            height: "80%",
            gap: "3%",
          }}
        >
          {values.map((v, i) => (
            <div
              key={i}
              style={{
                flex: 1,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                height: "100%",
                justifyContent: "flex-end",
              }}
            >
              <div
                style={{
                  width: "100%",
                  height: `${(v / maxV) * 100}%`,
                  background: `linear-gradient(180deg, ${FS.cyan}, #0070ff)`,
                  borderRadius: "25%",
                }}
              />
              <div
                style={{
                  marginTop: "8%",
                  fontSize: cW * 0.022,
                  color: "rgba(255,255,255,0.6)",
                }}
              >
                {days[i]}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// =============================================================================
// Preview — scales a full-resolution slide into a grid card via ResizeObserver
// =============================================================================

function ScreenshotPreview({
  slide,
  cW,
  cH,
  exportRef,
}: {
  slide: SlideDef;
  cW: number;
  cH: number;
  exportRef: (el: HTMLDivElement | null) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);

  useEffect(() => {
    if (!containerRef.current) return;
    const ro = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const { width } = entry.contentRect;
        setScale(width / cW);
      }
    });
    ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, [cW]);

  return (
    <div
      ref={containerRef}
      style={{
        position: "relative",
        width: "100%",
        aspectRatio: `${cW}/${cH}`,
        overflow: "hidden",
        borderRadius: 14,
        boxShadow: "0 4px 24px rgba(0,0,0,0.2)",
        background: "#000",
      }}
    >
      <div
        style={{
          width: cW,
          height: cH,
          transform: `scale(${scale})`,
          transformOrigin: "top left",
        }}
      >
        <slide.component cW={cW} cH={cH} />
      </div>

      {/* Offscreen hi-res copy for export */}
      <div
        ref={exportRef}
        style={{
          position: "absolute",
          left: "-9999px",
          top: 0,
          width: cW,
          height: cH,
          background: "#000",
        }}
      >
        <slide.component cW={cW} cH={cH} />
      </div>
    </div>
  );
}

// =============================================================================
// Main page
// =============================================================================

export default function ScreenshotsPage() {
  const [ready, setReady] = useState(false);
  const [sizeIdx, setSizeIdx] = useState(0);
  const [exporting, setExporting] = useState<string | null>(null);
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    preloadAllImages().then(() => setReady(true));
  }, []);

  if (!ready) {
    return (
      <div
        style={{
          minHeight: "100vh",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily: "system-ui",
          color: "#555",
        }}
      >
        Loading assets…
      </div>
    );
  }

  const cW = W;
  const cH = H;
  const currentSize = IPHONE_SIZES[sizeIdx];

  async function captureSlide(el: HTMLDivElement, w: number, h: number): Promise<string> {
    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "-1";

    const opts = { width: w, height: h, pixelRatio: 1, cacheBust: true };
    await toPng(el, opts); // warm
    const dataUrl = await toPng(el, opts); // real

    el.style.left = "-9999px";
    el.style.opacity = "";
    el.style.zIndex = "";
    return dataUrl;
  }

  async function exportAll() {
    for (let i = 0; i < SLIDES.length; i++) {
      setExporting(`${i + 1}/${SLIDES.length}`);
      const el = exportRefs.current[i];
      if (!el) continue;
      const dataUrl = await captureSlide(el, currentSize.w, currentSize.h);
      const a = document.createElement("a");
      a.href = dataUrl;
      a.download = `${String(i + 1).padStart(2, "0")}-${SLIDES[i].id}-${currentSize.w}x${currentSize.h}.png`;
      a.click();
      await new Promise((r) => setTimeout(r, 300));
    }
    setExporting(null);
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        background: "#f3f4f6",
        position: "relative",
        overflowX: "hidden",
      }}
    >
      {/* Toolbar */}
      <div
        style={{
          position: "sticky",
          top: 0,
          zIndex: 50,
          background: "white",
          borderBottom: "1px solid #e5e7eb",
          display: "flex",
          alignItems: "center",
        }}
      >
        <div
          style={{
            flex: 1,
            display: "flex",
            alignItems: "center",
            gap: 10,
            padding: "12px 18px",
            overflowX: "auto",
            minWidth: 0,
          }}
        >
          <span style={{ fontWeight: 700, fontSize: 14, whiteSpace: "nowrap" }}>
            FitScroll · App Store Screenshots
          </span>

          <select
            value={sizeIdx}
            onChange={(e) => setSizeIdx(Number(e.target.value))}
            style={{
              fontSize: 12,
              border: "1px solid #e5e7eb",
              borderRadius: 6,
              padding: "5px 10px",
            }}
          >
            {IPHONE_SIZES.map((s, i) => (
              <option key={i} value={i}>
                {s.label} — {s.w}×{s.h}
              </option>
            ))}
          </select>
        </div>

        <div
          style={{
            flexShrink: 0,
            padding: "10px 18px",
            borderLeft: "1px solid #e5e7eb",
          }}
        >
          <button
            onClick={exportAll}
            disabled={!!exporting}
            style={{
              padding: "8px 22px",
              background: exporting ? "#93c5fd" : "#2563eb",
              color: "white",
              border: "none",
              borderRadius: 8,
              fontSize: 12,
              fontWeight: 600,
              cursor: exporting ? "default" : "pointer",
              whiteSpace: "nowrap",
            }}
          >
            {exporting ? `Exporting… ${exporting}` : "Export All"}
          </button>
        </div>
      </div>

      {/* Grid */}
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))",
          gap: 24,
          padding: 24,
          maxWidth: 1800,
          margin: "0 auto",
        }}
      >
        {SLIDES.map((slide, i) => (
          <div key={slide.id}>
            <div
              style={{
                fontSize: 12,
                fontWeight: 600,
                color: "#6b7280",
                marginBottom: 8,
                textTransform: "uppercase",
                letterSpacing: 0.5,
              }}
            >
              {String(i + 1).padStart(2, "0")} · {slide.id}
            </div>
            <ScreenshotPreview
              slide={slide}
              cW={cW}
              cH={cH}
              exportRef={(el) => {
                exportRefs.current[i] = el;
              }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
