.pragma library

var data = {
    "disks": ["/"],
    "updateServiceEnabled": true,
    "idle": {
        "general": {
            "lock_cmd": "ambxst lock",
            "before_sleep_cmd": "loginctl lock-session",
            "after_sleep_cmd": "ambxst screen on"
        },
        "listeners": [
            {
                "timeout": 150,
                "onTimeout": "ambxst brightness 10 -s",
                "onResume": "ambxst brightness -r"
            },
            {
                "timeout": 300,
                "onTimeout": "loginctl lock-session"
            },
            {
                "timeout": 330,
                "onTimeout": "ambxst screen off",
                "onResume": "ambxst screen on"
            },
            {
                "timeout": 1800,
                "onTimeout": "ambxst suspend"
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
