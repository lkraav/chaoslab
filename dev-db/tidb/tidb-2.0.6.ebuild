# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# TODO: Add an init script and systemd unit file

GIT_COMMIT="b13bc08" # Change this when you update the ebuild
EGO_PN="github.com/pingcap/tidb"
EGO_VENDOR=( "github.com/coreos/gofail bdde102" )

inherit golang-vcs-snapshot

DESCRIPTION="A distributed NewSQL database compatible with MySQL protocol"
HOMEPAGE="https://pingcap.com/"
SRC_URI="https://${EGO_PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"
RESTRICT="mirror"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="pie test"

DOCS=( {CHANGELOG,README,docs/{QUICKSTART,ROADMAP}}.md )
QA_PRESTRIPPED="usr/bin/tidb-server"

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

src_prepare() {
	# The tarball isn't a proper git repository, so let's silence
	# the "fatal" error message. Also remove references to
	# "go get github.com/coreos/gofail"
	sed -i \
		-e '/LDFLAGS +/d' \
		-e '/coreos\/gofail/d' \
		Makefile || die

	default
}

src_compile() {
	export GOPATH="${G}"
	local myldflags=( -s -w
		-X "${EGO_PN}/mysql.TiDBReleaseVersion=${PV}"
		-X "'${EGO_PN}/util/printer.TiDBBuildTS=$(date -u '+%Y-%m-%d %I:%M:%S')'"
		-X "${EGO_PN}/util/printer.TiDBGitHash=${GIT_COMMIT}"
		-X "${EGO_PN}/util/printer.TiDBGitBranch=non-git"
		-X "'${EGO_PN}/util/printer.GoVersion=$(go version)'"
	)
	local mygoargs=(
		-v -work -x
		"-buildmode=$(usex pie pie default)"
		-asmflags "-trimpath=${S}"
		-gcflags "-trimpath=${S}"
		-ldflags "${myldflags[*]}"
		-o ./bin/tidb-server
	)

	emake parser

	go build "${mygoargs[@]}" ./tidb-server || die

	if use test; then
		go install ./vendor/github.com/coreos/gofail || die
	fi
}

src_test() {
	local PATH="${S}/bin:$PATH"
	emake gotest
}

src_install() {
	dobin bin/tidb-server
	einstalldocs
}

pkg_postinst() {
	einfo
	elog "See https://pingcap.com/docs/ for configuration guide."
	einfo
}
