/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import SnapKit
import UIKit
import Telemetry

class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    fileprivate let tableView = UITableView(frame: .zero, style: .grouped)

    // Hold a strong reference to the block detector so it isn't deallocated
    // in the middle of its detection.
    private let detector = BlockerEnabledDetector.makeInstance()

    private var isSafariEnabled = false
    private let searchEngineManager: SearchEngineManager

    private let toggles = [
        BlockerToggle(label: UIConstants.strings.toggleSafari, setting: SettingsToggle.safari),
        BlockerToggle(label: UIConstants.strings.labelBlockAds, setting: SettingsToggle.blockAds),
        BlockerToggle(label: UIConstants.strings.labelBlockAnalytics, setting: SettingsToggle.blockAnalytics),
        BlockerToggle(label: UIConstants.strings.labelBlockSocial, setting: SettingsToggle.blockSocial),
        BlockerToggle(label: UIConstants.strings.labelBlockOther, setting: SettingsToggle.blockOther, subtitle: UIConstants.strings.settingsToggleOtherSubtitle),
        BlockerToggle(label: UIConstants.strings.labelBlockFonts, setting: SettingsToggle.blockFonts),
        BlockerToggle(label: UIConstants.strings.labelSendAnonymousUsageData, setting: SettingsToggle.sendAnonymousUsageData),
    ]

    /// Used to calculate cell heights.
    private lazy var dummyToggleCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "dummyCell")
        cell.accessoryView = PaddedSwitch(switchView: UISwitch())
        return cell
    }()

    init(searchEngineManager: SearchEngineManager) {
        self.searchEngineManager = searchEngineManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        view.backgroundColor = UIConstants.colors.background

        title = UIConstants.strings.settingsTitle

        let navigationBar = navigationController!.navigationBar
        navigationBar.isTranslucent = false
        navigationBar.barTintColor = UIConstants.colors.background
        navigationBar.tintColor = UIConstants.colors.navigationButton
        navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIConstants.colors.navigationTitle]

        let aboutButton = UIBarButtonItem(title: UIConstants.strings.aboutTitle, style: .plain, target: self, action: #selector(aboutClicked))
        aboutButton.image = #imageLiteral(resourceName: "about_icon")
        aboutButton.accessibilityIdentifier = "SettingsViewController.aboutButton"
        navigationItem.rightBarButtonItem = aboutButton

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(self.view)
        }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIConstants.colors.background
        tableView.layoutMargins = UIEdgeInsets.zero
        tableView.separatorColor = UIConstants.colors.settingsSeparator
        tableView.allowsSelection = true
        tableView.estimatedRowHeight = 44

        toggles.forEach { blockerToggle in
            let toggle = blockerToggle.toggle
            toggle.onTintColor = UIConstants.colors.toggleOn
            toggle.tintColor = UIConstants.colors.toggleOff
            toggle.addTarget(self, action: #selector(toggleSwitched(_:)), for: .valueChanged)
            toggle.isOn = Settings.getToggle(blockerToggle.setting)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        updateSafariEnabledState()
    }

    @objc private func applicationDidBecomeActive() {
        // On iOS 9, we detect the blocker status by loading an invisible SafariViewController
        // in the current view. We can only run the detector if the view is visible; otherwise,
        // the detection callback won't fire and the detector won't be cleaned up.
        if isViewLoaded && view.window != nil {
            updateSafariEnabledState()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    fileprivate func toggleForIndexPath(_ indexPath: IndexPath) -> BlockerToggle {
        var index = (indexPath as NSIndexPath).row
        for i in 1..<(indexPath as NSIndexPath).section {
            index += tableView.numberOfRows(inSection: i)
        }
        return toggles[index]
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 4 {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.detailTextLabel?.text = UIConstants.strings.subtitleSendAnonymousUsageData
            cell.detailTextLabel?.textColor = UIConstants.colors.toggleOn
            cell.accessibilityIdentifier = "SettingsViewController.learnMoreCell"
            cell.selectionStyle = .none
            cell.backgroundColor = UIConstants.colors.background
            cell.layoutMargins = UIEdgeInsets.zero

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedLearnMoreFooter))
            cell.addGestureRecognizer(tapGesture)

            return cell
        }
        return nil
    }

    func tappedLearnMoreFooter(gestureRecognizer: UIGestureRecognizer) {
        guard let url = SupportUtils.URLForTopic(topic: "usage-data") else { return }
        let contentViewController = AboutContentViewController(url: url)
        navigationController?.pushViewController(contentViewController, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 4 ? 40 : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        switch (indexPath as NSIndexPath).section {
        case 0:
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "searchCell")
            cell.textLabel?.text = searchEngineManager.activeEngine.name
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "SettingsViewController.searchCell"
        default:
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "toggleCell")
            let toggle = toggleForIndexPath(indexPath)
            cell.textLabel?.text = toggle.label
            cell.textLabel?.numberOfLines = 0
            cell.accessoryView = PaddedSwitch(switchView: toggle.toggle)
            cell.detailTextLabel?.text = toggle.subtitle
            cell.detailTextLabel?.numberOfLines = 0
            cell.selectionStyle = .none
        }

        cell.backgroundColor = UIConstants.colors.background
        cell.textLabel?.textColor = UIConstants.colors.settingsTextLabel
        cell.layoutMargins = UIEdgeInsets.zero
        cell.detailTextLabel?.textColor = UIConstants.colors.settingsDetailLabel

        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Search Engine.
        case 1: return 1 // Integration.
        case 2: return 4 // Privacy.
        case 3: return 1 // Performance.
        case 4: return 1 // Mozilla.
        default:
            assertionFailure("Invalid section")
            return 0
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Height for the Search Engine and Learn More row.
        if indexPath.section == 0 || (indexPath.section == 4 && indexPath.row == 1) {
            return 44
        }

        // We have to manually calculate the cell height since UITableViewCell doesn't correctly
        // layout multiline detailTextLabels.
        let toggle = toggleForIndexPath(indexPath)
        let tableWidth = tableView.frame.width
        let accessoryWidth = dummyToggleCell.accessoryView!.frame.width
        let insetsWidth = 2 * tableView.separatorInset.left
        let width = tableWidth - accessoryWidth - insetsWidth

        var height = heightForLabel(dummyToggleCell.textLabel!, width: width, text: toggle.label)
        if let subtitle = toggle.subtitle {
            height += heightForLabel(dummyToggleCell.detailTextLabel!, width: width, text: subtitle)
        }

        return height + 22
    }

    private func heightForLabel(_ label: UILabel, width: CGFloat, text: String) -> CGFloat {
        let size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let attrs: [String: Any] = [NSFontAttributeName: label.font]
        let boundingRect = NSString(string: text).boundingRect(with: size, options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: attrs, context: nil)
        return boundingRect.height
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let labelText: String

        switch section {
        case 0: labelText = UIConstants.strings.settingsSearchSection
        case 1: labelText = UIConstants.strings.toggleSectionIntegration
        case 2: labelText = UIConstants.strings.toggleSectionPrivacy
        case 3: labelText = UIConstants.strings.toggleSectionPerformance
        case 4: labelText = UIConstants.strings.toggleSectionMozilla
        default: return nil
        }

        // Hack: We want the header view's margin to match the cells, so we create an empty
        // cell with a blank space as text to layout the text label. From there, we can define
        // constraints for our custom label based on the cell's label.
        let cell = UITableViewCell()
        cell.textLabel?.text = " "
        cell.backgroundColor = UIConstants.colors.background

        let label = UILabel()
        label.text = labelText
        label.textColor = UIConstants.colors.tableSectionHeader
        label.font = UIConstants.fonts.tableSectionHeader
        cell.contentView.addSubview(label)

        label.snp.makeConstraints { make in
            make.leading.trailing.equalTo(cell.textLabel!)
            make.centerY.equalTo(cell.textLabel!).offset(10)
        }

        // Hack to cover header separator line
        let footer = UIView()
        footer.backgroundColor = UIConstants.colors.background

        cell.addSubview(footer)

        footer.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.bottom.equalToSuperview().offset(1)
            make.leading.trailing.equalToSuperview()
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.section {
        case 0:
            let searchSettingsViewController = SearchSettingsViewController(searchEngineManager: searchEngineManager)
            searchSettingsViewController.delegate = self
            navigationController?.pushViewController(searchSettingsViewController, animated: true)
        default: break
        }
    }

    private func updateSafariEnabledState() {
        let safariToggle = self.toggles.first { $0.setting == .safari }!.toggle

        safariToggle.isEnabled = false

        detector.detectEnabled(view) { [weak self] enabled in
            safariToggle.isOn = enabled && Settings.getToggle(.safari)
            safariToggle.isEnabled = true
            self?.isSafariEnabled = enabled
        }
    }

    @objc private func aboutClicked() {
        navigationController!.pushViewController(AboutViewController(), animated: true)
    }

    @objc private func toggleSwitched(_ sender: UISwitch) {
        let toggle = toggles.filter { $0.toggle == sender }.first!

        func updateSetting() {
            let telemetryEvent = TelemetryEvent(category: TelemetryEventCategory.action, method: TelemetryEventMethod.change, object: "setting", value: toggle.setting.rawValue)
            telemetryEvent.addExtra(key: "to", value: sender.isOn)
            Telemetry.default.recordEvent(telemetryEvent)

            Settings.set(sender.isOn, forToggle: toggle.setting)
            Utils.reloadSafariContentBlocker()
            LocalContentBlocker.reload()
        }

        // First check if the user changed the anonymous usage data setting and follow that choice right
        // here. Otherwise it will be delayed until the application restarts.
        if toggle.setting == .sendAnonymousUsageData {
            Telemetry.default.configuration.isCollectionEnabled = sender.isOn
            Telemetry.default.configuration.isUploadEnabled = sender.isOn
        }

        switch toggle.setting {
        case .safari where sender.isOn && !isSafariEnabled:
            let instructionsViewController = SafariInstructionsViewController()
            navigationController!.pushViewController(instructionsViewController, animated: true)
            updateSetting()
        case .blockOther where sender.isOn:
            let alertController = UIAlertController(title: nil, message: UIConstants.strings.settingsBlockOtherMessage, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: UIConstants.strings.settingsBlockOtherNo, style: UIAlertActionStyle.default) { _ in
                sender.isOn = false
                updateSetting()
            })
            alertController.addAction(UIAlertAction(title: UIConstants.strings.settingsBlockOtherYes, style: UIAlertActionStyle.destructive) { _ in
                updateSetting()
            })
            alertController.popoverPresentationController?.sourceView = sender
            alertController.popoverPresentationController?.sourceRect = sender.bounds
            present(alertController, animated: true, completion: nil)
        default:
            updateSetting()
        }
    }
}

extension SettingsViewController: SearchSettingsViewControllerDelegate {
    func searchSettingsViewController(_ searchSettingsViewController: SearchSettingsViewController, didSelectEngine engine: SearchEngine) {
        tableView.cellForRow(at: IndexPath(row: 0, section: 0))?.textLabel?.text = engine.name
    }
}

private class PaddedSwitch: UIView {
    private static let Padding: CGFloat = 8

    init(switchView: UISwitch) {
        super.init(frame: CGRect.zero)

        addSubview(switchView)

        frame.size = CGSize(width: switchView.frame.width + PaddedSwitch.Padding, height: switchView.frame.height)
        switchView.frame.origin = CGPoint(x: PaddedSwitch.Padding, y: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class BlockerToggle {
    let toggle = UISwitch()
    let label: String
    let setting: SettingsToggle
    let subtitle: String?

    init(label: String, setting: SettingsToggle, subtitle: String? = nil) {
        self.label = label
        self.setting = setting
        self.subtitle = subtitle
        toggle.accessibilityIdentifier = "BlockerToggle.\(setting.rawValue)"
    }
}
