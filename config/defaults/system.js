.pragma library

var data = {
    "disks": ["/"],
    "updateServiceEnabled": true,
    "batteryNotifications": {
        "enabled": true,
        "lowThreshold": 20,
        "criticalThreshold": 10
    },
    "idle": {
        "general": {
            "lock_cmd": "nothingless lock",
            "before_sleep_cmd": "loginctl lock-session",
            "after_sleep_cmd": "nothingless screen on"
        },
        "listeners": [
            {
                "timeout": 150,
                "onTimeout": "nothingless brightness 10 -s",
                "onResume": "nothingless brightness -r"
            },
            {
                "timeout": 300,
                "onTimeout": "loginctl lock-session"
            },
            {
                "timeout": 330,
                "onTimeout": "nothingless screen off",
                "onResume": "nothingless screen on"
            },
            {
                "timeout": 1800,
                "onTimeout": "nothingless suspend"
            }
        ]
    },
    "ocr": {
        "eng": true,
        "spa": true,
        "lat": false,
        "jpn": false,
        "chi_sim": false,
        "chi_tra": false,
        "kor": false
    },
    "pomodoro": {
        "workTime": 1500,
        "restTime": 300,
        "autoStart": false,
        "syncSpotify": false
    }
}
