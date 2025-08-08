//
//  AppIntent.swift
//  FavoritesWidget
//
//  Created by Platon on 08.08.2025.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent, AppIntent {
    static var title: LocalizedStringResource { "Конфигурация виджета" }
    static var description: IntentDescription { "Выберите доску для загрузки в случае отсутствия доступа к данным приложения." }

    @Parameter(title: "Код доски", default: "b")
    var boardCode: String

    static var openAppWhenRun: Bool { true }
}
