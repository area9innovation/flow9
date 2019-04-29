// documentation for this shit:
// https://doc.qt.io/qtinstallerframework/noninteractive.html
//
function Controller() {
    installer.autoRejectMessageBoxes();
    installer.installationFinished.connect(function() {
        gui.clickButton(buttons.NextButton);
    })
}

Controller.prototype.WelcomePageCallback = function() {
    // arcane knowledge from the internet. Apparently this is required for reliably
    // installing qt since next button is not available right away
    gui.clickButton(buttons.NextButton, 3000);
}

Controller.prototype.CredentialsPageCallback = function() {
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.IntroductionPageCallback = function() {
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.TargetDirectoryPageCallback = function()
{
    // This will not be the final folder. Installer also adds 5.6/gcc_64 to it
    gui.currentPageWidget().TargetDirectoryLineEdit.setText("%INSTALL_PATH%");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ComponentSelectionPageCallback = function() {
    var widget = gui.currentPageWidget();
    widget.selectAll();
    // Commented out and left for reference so that you won't have to google those 
    // widget.deselectAll();
    // component selection does not work as expected
    // To experiment, you can do selectAll() and then examine components.xml
    // in resulting installation.
    // TODO: below lines don't work. Instead examples and docs are removed in Dockerfile
    // consider fixing.
    // widget.deselectComponent("qt.59.examples");
    // widget.deselectComponent("qt.59.doc");
    // widget.selectComponent("qt.59.gcc_64");
    // widget.deselectComponent("qt.tools.qtcreator");

    gui.clickButton(buttons.NextButton);
}

Controller.prototype.LicenseAgreementPageCallback = function() {
    gui.currentPageWidget().AcceptLicenseRadioButton.setChecked(true);
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.StartMenuDirectoryPageCallback = function() {
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ReadyForInstallationPageCallback = function()
{
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.FinishedPageCallback = function() {
var checkBoxForm = gui.currentPageWidget().LaunchQtCreatorCheckBoxForm
if (checkBoxForm && checkBoxForm.launchQtCreatorCheckBox) {
    checkBoxForm.launchQtCreatorCheckBox.checked = false;
}
    gui.clickButton(buttons.FinishButton);
}


