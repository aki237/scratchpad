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

module src.main;


private import src.spec;

private import gio.Application : GioApplication = Application;
private import gtk.Application;
private import gtkc.gtktypes;
private import gtk.ApplicationWindow;
private import gtk.Window;
private import gobject.Signals;
private import gobject.Type;

private import gtk.Overlay;
private import gtk.FileChooserDialog;
private import gtk.ScrolledWindow;
private import gtk.Button;
private import gtk.Paned;
private import gtk.Box;
private import gtk.Entry;
private import gtk.HeaderBar;
private import gtk.Popover;
private import gtk.MessageDialog;
private import gtk.ComboBoxText;
private import gtk.Spinner;
private import gtk.Label;
private import gtk.AccelGroup;
private import vte.Terminal;

private import gsv.SourceView;
private import gsv.SourceBuffer;
private import gsv.SourceLanguage;
private import gsv.SourceLanguageManager;
private import gsv.SourceBuffer;

private import gtk.Widget;
private import glib.Str;

private import std.net.curl;
private import std.stdio;
private import std.file;
private import std.array;
private import std.format;
private import core.sys.posix.signal;
private import std.uri;
private import gtk.EditableIF;
private import core.thread;

extern (C) void callback(void* userData) {
  printf("Called callbak!!");
}

extern (C) void* ud;

class Scratchpad : ApplicationWindow {
  ScrolledWindow esr, osr;
  SourceView ligoFactory;
  Terminal output;
  Paned splitter;
  HeaderBar titlebar;
  Button run, gist, fetch, langSelector, save;
  Entry srcBox;
  Popover pp;
  ComboBoxText lang;
  int ligoProcess;
  Spec[] specs;
  Overlay ol;
  Spec currentSpec;
  AccelGroup acc;

  void writeToFile(string filename) {
    SourceBuffer sb = ligoFactory.getBuffer();
    File* fh = new File (filename, "w");
    fh.write(sb.getText());
    fh.close();
  }
  
  void getRemoteCode() {
    Spinner sp = new Spinner();
    titlebar.packEnd(sp);
    ligoFactory.setSensitive(false);
    titlebar.showAll();
    sp.start();
    try {
      auto content = get(srcBox.getText());
      auto sb = ligoFactory.getBuffer();
      sb.setText(cast(string)(content));
      srcBox.setText("");
    } catch (CurlException e) {
      MessageDialog d = new MessageDialog(this, DialogFlags.USE_HEADER_BAR,MessageType.ERROR,ButtonsType.CLOSE, "Error encountered while trying to fetch the url.");
      d.run();
      d.destroy();
    }
    ligoFactory.setSensitive(true);
    sp.stop();
    titlebar.remove(sp);
  }
  
  public void processExited(int statusCode, Terminal term) {
    output.feed(format("\n[process exited with %d status code]", statusCode));
    ligoFactory.grabFocus();
    run.setSensitive(true);
  }

  public void runLigoCode(Button btn) {
    run.setSensitive(false);
    string filename = "/tmp/raw." ~ currentSpec.getExtension();
    writeToFile(filename);

    output.reset(true, true);
    output.spawnSync(VtePtyFlags.DEFAULT,
                     "/tmp/",
                     currentSpec.getArgs() ~ [filename],
                     array([""]),
                     GSpawnFlags.DEFAULT,
                     &callback,
                     ud,
                     ligoProcess,
                     null);
    output.grabFocus();
  }

  
  this(Application app) {
    super(app);
    setSizeRequest(800, 600);

    this.addOnSizeAllocate(delegate(Allocation a, Widget wid) {
        splitter.setPosition(a.width/2);
      });

    acc = new AccelGroup();
    this.addAccelGroup(acc);

    // Setup Headerbar//
    titlebar = new HeaderBar();
    setTitlebar(titlebar);
    titlebar.setShowCloseButton(true);
    titlebar.setTitle("Scratchpad");
    titlebar.setSubtitle("Programming environment");

    // Setup run button//
    run = new Button("▶", true);
    run.setTooltipText("Build/Run the snippet (Ctrl-B)");

    gist = new Button("🗎", true);
    gist.setTooltipText("Fetch remote snippet (Ctrl-O)");

    gist.addOnClicked(delegate(Button btn){
        pp.showAll();
      });

    save = new Button("💾");
    save.addOnClicked(delegate(Button btn) {
        auto fsaver = new FileChooserDialog("Save Snippet as...",this,FileChooserAction.SAVE);
        int status = fsaver.run();
        if (status == ResponseType.ACCEPT) {
          writeToFile(fsaver.getFilename());
        }
        fsaver.destroy();
      });
    
    save.setTooltipText("Build/Run the snippet (Ctrl-S)");
    
    specs = [
             new Spec(["ligo"], "lg", "Ligo", "scheme"),
             new Spec(["go","run"], "go", "Go", "go"),
             new Spec(["python2"], "py", "Python 2", "python"),
             new Spec(["python3"], "py", "Python 3", "python3"),
             new Spec(["bash"], "sh", "Bash Script", "sh"),
             new Spec(["lua"], "lua", "Lua", "lua"),
             new Spec(["ruby"], "rb", "Ruby", "ruby"),
             new Spec(["perl"], "pl", "Perl", "perl"),
             new Spec(["rdmd"], "d", "D", "d"),
             new Spec(["node"], "js", "Javascript", "javascript"),
             new Spec(["gjs"], "js", "Gnome Js", "javascript"),
             ];
    currentSpec = specs[8];

    langSelector = new Button("D", true);
    langSelector.setTooltipText("Change run configuration (Ctrl-L)");
    Popover langContainer = new Popover(langSelector);
    langSelector.addOnClicked(delegate(Button btn){
        langContainer.showAll();
      });
    lang = new ComboBoxText();
    lang.addOnChanged(delegate(ComboBoxText ct) {
        string g = ct.getActiveText();
        foreach (spec ; specs) {
          if (g == spec.getLanguage()) {
            currentSpec = spec;
            setLanguage(spec);
            langSelector.setLabel(g);
            langContainer.hide();
            return;
          }
        }
      });
    
    langContainer.add(lang);
    foreach (spec ; specs) {
      lang.appendText(spec.getLanguage());
    }

    titlebar.packEnd(langSelector);
    
    titlebar.add(run);
    titlebar.add(gist);
    titlebar.add(save);


    // Setting up popup
    pp = new Popover(gist);
    Box box = new Box(Orientation.HORIZONTAL, 0);
    pp.add(box);
    fetch = new Button("🞋", true);
    fetch.setSensitive(false);
    srcBox = new Entry();
    srcBox.setPlaceholderText("Enter gist url...");
    srcBox.addOnChanged(delegate(EditableIF e) {
        string uri = srcBox.getText();
        if (uri == "") {
          fetch.setSensitive(false);
          return;
        }
        fetch.setSensitive(true);
      });
    box.add(srcBox);
    box.add(fetch);
    srcBox.addOnActivate(delegate(Entry) {
        auto composed = new Thread(&getRemoteCode).start();
        pp.hide();
      });
    
    fetch.addOnClicked(delegate(Button btn){
        auto composed = new Thread(&getRemoteCode).start();
        pp.hide();
      });

    // Setup paned view//
    splitter = new Paned(Orientation.HORIZONTAL);
    add(splitter);

    ligoFactory = new SourceView();
    ligoFactory.setShowLineNumbers(true);

    
    uint key;
    GdkModifierType mod;
    AccelGroup.acceleratorParse("<Control>B", key, mod);
    run.addAccelerator("clicked", acc, key, mod, AccelFlags.VISIBLE);

    AccelGroup.acceleratorParse("<Control>L", key, mod);
    langSelector.addAccelerator("clicked", acc, key, mod, AccelFlags.VISIBLE);
    
    AccelGroup.acceleratorParse("<Control>O", key, mod);
    gist.addAccelerator("clicked", acc, key, mod, AccelFlags.VISIBLE);

    AccelGroup.acceleratorParse("<Control>S", key, mod);
    save.addAccelerator("clicked", acc, key, mod, AccelFlags.VISIBLE);

    ligoFactory.setInsertSpacesInsteadOfTabs(false);
    ligoFactory.setTabWidth(4);
    //ligoFactory.setHighlightCurrentLine(true);

    setLanguage(currentSpec);

    ligoFactory.modifyFont("Source Code Pro", 13);
    ligoFactory.setRightMarginPosition(72);
    ligoFactory.setShowRightMargin(true);
    ligoFactory.setAutoIndent(true);

    esr = new ScrolledWindow();
    esr.add(ligoFactory);
    splitter.add1(esr);

    // ol = new Overlay();
    // ol.add(esr);
    // Label ll =  new Label("This is some label.... This is so awesome.....");
    // ol.addOverlay(ll);
    // splitter.add1(ol);

    output = new Terminal();
    output.addOnChildExited(&processExited);

    
    osr = new ScrolledWindow();
    osr.add(output);
    splitter.add2(osr);
    splitter.setPosition(400);

    ligoFactory.grabFocus() ;


    run.addOnClicked(&runLigoCode);
    
    showAll();
  }

  void setLanguage(Spec lang) {
    SourceBuffer sb = ligoFactory.getBuffer();
    SourceLanguageManager slm = new SourceLanguageManager();
    SourceLanguage sl = slm.getLanguage(lang.getCode());

    if ( sl !is null ) {
      sb.setLanguage(sl);
      sb.setHighlightSyntax(true);
    }
  }
  
}


int main(string[] args) {
  auto application = new Application("org.aki237.scratchpad", GApplicationFlags.FLAGS_NONE);
  application.addOnActivate(delegate (GioApplication app) { new Scratchpad(application); });
  return application.run(null);
}
