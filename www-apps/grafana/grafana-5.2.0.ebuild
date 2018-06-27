# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

EGO_PN="github.com/${PN}/${PN}"
GIT_COMMIT="ad4d717" # Change this when you update the ebuild

inherit golang-vcs-snapshot systemd user

DESCRIPTION="Grafana is an open source metric analytics & visualization suite"
HOMEPAGE="https://grafana.com"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
RESTRICT="mirror"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="pie"

RDEPEND="!www-apps/grafana-bin"
DEPEND=">=net-libs/nodejs-6
	sys-apps/yarn"

DOCS=( CHANGELOG.md README.md )

QA_PRESTRIPPED="usr/bin/grafana-cli
	usr/bin/grafana-server
	usr/libexec/grafana/phantomjs"

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	# shellcheck disable=SC2086
	if has network-sandbox $FEATURES; then
		ewarn ""
		ewarn "${CATEGORY}/${PN} requires 'network-sandbox' to be disabled in FEATURES"
		ewarn ""
		die "'network-sandbox' is enabled in FEATURES"
	fi

	enewgroup grafana
	enewuser grafana -1 -1 /usr/share/grafana grafana
}

src_prepare() {
	# Unfortunately 'network-sandbox' needs to disabled
	# because yarn/npm fetches some dependencies here:
	emake deps
	default
}

src_compile() {
	export GOPATH="${G}"
	export GOBIN="${S}/bin"
	local myldflags=( -s -w
		-X "main.version=${PV}"
		-X "main.commit=${GIT_COMMIT}"
		-X "main.buildstamp=$(date -u '+%s')"
	)
	local mygoargs=(
		-v -work -x
		"-buildmode=$(usex pie pie default)"
		-asmflags "-trimpath=${S}"
		-gcflags "-trimpath=${S}"
		-ldflags "${myldflags[*]}"
	)
	go install "${mygoargs[@]}" ./pkg/cmd/grafana-{cli,server} || die

	emake build-js
}

src_test() {
	emake test-go test-js
}

src_install() {
	dobin bin/grafana-{cli,server}
	einstalldocs

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"
	systemd_dounit "${FILESDIR}/${PN}.service"

	exeinto /usr/libexec/grafana
	doexe tools/phantomjs/phantomjs
	scanelf -Xe "${ED%/}/usr/libexec/grafana/phantomjs" || die

	insinto /etc/grafana
	newins conf/sample.ini grafana.ini.example

	insinto /usr/share/grafana/conf
	doins conf/{defaults.ini,ldap.toml}

	insinto /usr/share/grafana
	doins -r public

	insinto /usr/share/grafana/tools/phantomjs
	doins tools/phantomjs/render.js
	dosym ../../../../libexec/grafana/phantomjs \
		/usr/share/grafana/tools/phantomjs/phantomjs

	diropts -o grafana -g grafana -m 0750
	keepdir /var/log/grafana
	keepdir /var/lib/grafana/{dashboards,plugins}
}

pkg_postinst() {
	if [[ $(stat -c %a "${EROOT%/}/var/lib/grafana") != "750" ]]; then
		einfo "Fixing ${EROOT%/}/var/lib/grafana permissions"
		chown grafana:grafana "${EROOT%/}/var/lib/grafana" || die
		chmod 0750 "${EROOT%/}/var/lib/grafana" || die
	fi

	if [[ ! -f "${EROOT%/}"/etc/grafana/grafana.ini ]]; then
		elog "No grafana.ini found, copying the example over"
		cp "${EROOT%/}"/etc/grafana/grafana.ini{.example,} || die
	else
		elog "grafana.ini found, please check example file for possible changes"
	fi
	einfo ""
	elog "${PN} has built-in log rotation. Please see [log.file] section of"
	elog "${EROOT%/}/etc/grafana/grafana.ini for related settings."
	einfo ""
	elog "You may add your own custom configuration for app-admin/logrotate if you"
	elog "wish to use external rotation of logs. In this case, you also need to make"
	elog "sure the built-in rotation is turned off."
	einfo ""
}
