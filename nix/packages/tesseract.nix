{ pkgs }:

[
  (pkgs.tesseract.override {
    enableLanguages = [
      "eng"
      "spa"
      "lat"
      "jpn"
      "chi_sim"
      "chi_tra"
      "kor"
    ];
  })
]
