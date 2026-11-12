#!/usr/bin/env bash
# Update the translations: extract the strings of the widget into
# template.pot, bring every catalog (*.po) up to date with it, and compile
# the catalogs into the package.
#
# Usage: translations/build.sh        (needs gettext)
#
# To start a new translation, copy template.pot to <language>.po, translate
# it and run this script again.
set -euo pipefail
cd "$(dirname "$0")"

package=../package
id=$(sed -n 's/^ *"Id": *"\([^"]*\)".*/\1/p' "$package/metadata.json")
bugs=$(sed -n 's/^ *"BugReportUrl": *"\([^"]*\)".*/\1/p' "$package/metadata.json")
# Plasma looks the strings of a widget up in the domain named after its id.
domain="plasma_applet_$id"

# Only the keywords listed here are extracted (the bare --keyword drops the
# default ones). i18nd() and i18ndc() are left out on purpose: their strings
# belong to another domain and are translated there.
(cd "$package" && find contents -name '*.qml' | sort | xargs xgettext \
    --from-code=UTF-8 --c++ --kde --keyword \
    --keyword=i18n:1 --keyword=i18nc:1c,2 --keyword=i18np:1,2 --keyword=i18ncp:1c,2,3 \
    --add-comments=i18n --add-location=file \
    --package-name="$id" --msgid-bugs-address="$bugs" \
    --output="$OLDPWD/template.pot")
# The creation date would change the template, and every catalog with it,
# each time this script runs.
sed -i '/^"POT-Creation-Date:/d' template.pot

rm -rf "$package/contents/locale"
for catalog in *.po; do
    language=${catalog%.po}
    msgmerge --quiet --update --backup=none --no-fuzzy-matching --add-location=file "$catalog" template.pot
    # Strings that are gone from the widget are not kept around.
    msgattrib --no-obsolete --output-file="$catalog" "$catalog"
    target="$package/contents/locale/$language/LC_MESSAGES"
    mkdir -p "$target"
    printf '%s: ' "$language"
    msgfmt --check-format --statistics --output-file="$target/$domain.mo" "$catalog"
done
