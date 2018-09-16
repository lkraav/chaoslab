# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

EGO_PN="github.com/influxdata/${PN}"
EGO_VENDOR=( "github.com/kevinburke/go-bindata 06af60a" )
GIT_COMMIT="8ba2980" # Change this when you update the ebuild

inherit golang-vcs-snapshot systemd user

DESCRIPTION="Open source monitoring and visualization UI for the TICK stack"
HOMEPAGE="https://www.influxdata.com"
SRC_URI="https://${EGO_PN}/archive/${PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"
RESTRICT="mirror"

LICENSE="AGPL-3+"
SLOT="0"
KEYWORDS="~amd64"

DEPEND="
	<=net-libs/nodejs-9
	sys-apps/yarn
"

DOCS=( CHANGELOG.md )
QA_PRESTRIPPED="
	usr/bin/chronoctl
	usr/bin/chronograf
"

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	# shellcheck disable=SC2086
	if has network-sandbox $FEATURES; then
		ewarn ""
		ewarn "${CATEGORY}/${PN} requires 'network-sandbox' to be disabled in FEATURES"
		ewarn ""
		die "[network-sandbox] is enabled in FEATURES"
	fi

	enewgroup chronograf
	enewuser chronograf -1 -1 /var/lib/chronograf chronograf
}

src_prepare() {
	# The tarball isn't a proper git repository,
	# so let's silence the "fatal" error message.
	sed -e "/VERSION ?=/d" -e "/COMMIT ?=/d" -i Makefile || die

	emake .jsdep
	default
}

src_compile() {
	export GOPATH="${G}"
	local PATH="${G}/bin:$PATH"

	# Build go-bindata locally
	go install ./vendor/github.com/kevinburke/go-bindata/go-bindata || die
	touch .godep || die

	make VERSION="${PV}" COMMIT="${GIT_COMMIT}" build || die
}

src_install() {
	dobin chronoctl chronograf
	einstalldocs

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"
	systemd_dounit "etc/scripts/${PN}.service"

	dodir /usr/share/chronograf/resources
	insinto /usr/share/chronograf/canned
	doins canned/*.json

	insinto /etc/logrotate.d
	newins etc/scripts/logrotate chronograf

	diropts -o chronograf -g chronograf -m 0750
	keepdir /var/log/chronograf
}

pkg_postinst() {
	if [[ $(stat -c %a "${EROOT%/}/var/lib/chronograf") != "750" ]]; then
		einfo "Fixing ${EROOT%/}/var/lib/chronograf permissions"
		chown chronograf:chronograf "${EROOT%/}/var/lib/chronograf" || die
		chmod 0750 "${EROOT%/}/var/lib/chronograf" || die
	fi
}