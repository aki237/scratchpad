// Copyright (C) 2017 Akilan Elango <akilan1997@gmail.com>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module src.spec;

class Spec {
  string[] shArgs;
  string extension;
  string language;
  string code;

  this (string[] args, string ext, string lang, string c) {
    shArgs = args;
    extension = ext;
    language = lang;
    code = c;
  }

  string[] getArgs() {
    return ["/usr/bin/env"] ~ shArgs;
  }
  
  string getExtension() {
    return extension;
  }

  string getLanguage() {
    return language;
  }

  string getCode() {
    return code;
  }
}
