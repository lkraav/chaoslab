# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# Change this when you update the ebuild:
GIT_COMMIT="6cf8875f29f9c2b65b8eb5918a39e3aa819b7ed0"
EGO_PN="github.com/oliver006/${PN}"

inherit golang-vcs-snapshot systemd user

DESCRIPTION="A server that export Redis metrics for Prometheus consumption"
HOMEPAGE="https://github.com/oliver006/redis_exporter"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"
RESTRICT="mirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="pie test"

DOCS=( README.md )
QA_PRESTRIPPED="usr/bin/redis_exporter"

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

pkg_setup() {
	if use test; then
		ewarn ""
		ewarn "The test phase requires a local Redis server running on default port"
		ewarn ""
		# shellcheck disable=SC2086
		if has network-sandbox $FEATURES; then
			ewarn ""
			ewarn "The test phase requires 'network-sandbox' to be disabled in FEATURES"
			ewarn ""
			die "[network-sandbox] is enabled in FEATURES"
		fi
	fi

	enewgroup redis_exporter
	enewuser redis_exporter -1 -1 -1 redis_exporter
}

src_compile() {
	export GOPATH="${G}"
	local myldflags=( -s -w
		-X "main.VERSION=${PV}"
		-X "main.COMMIT_SHA1=${GIT_COMMIT}"
		-X "main.BUILD_DATE=$(date +%F-%T)"
	)
	local mygoargs=(
		-v -work -x
		"-buildmode=$(usex pie pie default)"
		-asmflags "-trimpath=${S}"
		-gcflags "-trimpath=${S}"
		-ldflags "${myldflags[*]}"
	)
	go build "${mygoargs[@]}" || die
}

src_test() {
	go test -v ./... || die
}

src_install() {
	dobin redis_exporter
	einstalldocs

	newinitd "${FILESDIR}/${PN}.initd" "${PN}"
	newconfd "${FILESDIR}/${PN}.confd" "${PN}"
	systemd_dounit "${FILESDIR}/${PN}.service"

	insinto /usr/share/redis_exporter
	doins -r contrib/*
	docompress -x /usr/share/redis_exporter

	diropts -o redis_exporter -g redis_exporter -m 0750
	keepdir /var/log/redis_exporter
}