# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

# Change this when you update the ebuild:
GIT_COMMIT="e1fcaf58d8313d186bce0b923b38e2fd0002bd6d"
EGO_PN="github.com/tsenart/${PN}"
# Keep EGO_VENDOR in sync with Gopkg.lock
EGO_VENDOR=(
	"github.com/alecthomas/jsonschema f2c9385"
	"github.com/lucasb-eyer/go-colorful 8abd3be"
	"github.com/streadway/quantile b0c5887"
	"golang.org/x/net 2491c5d github.com/golang/net"
	"golang.org/x/text f21a4df github.com/golang/text"
)

inherit golang-vcs-snapshot

DESCRIPTION="HTTP load testing tool and library. It's over 9000!"
HOMEPAGE="https://github.com/tsenart/vegeta"
SRC_URI="https://${EGO_PN}/archive/cli/v${PV}.tar.gz -> ${P}.tar.gz
	${EGO_VENDOR_URI}"
RESTRICT="mirror"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

DOCS=( CHANGELOG README.md )

G="${WORKDIR}/${P}"
S="${G}/src/${EGO_PN}"

QA_PRESTRIPPED="usr/bin/vegeta"

src_compile() {
	export GOPATH="${G}"
	local myldflags=( -s -w
		-X "main.Version=${PV}"
		-X "main.Commit=${GIT_COMMIT}"
		-X "'main.Date=$(date -u '+%Y-%m-%dT%TZ')'"
	)
	local mygoargs=(
		-v -work -x
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
	dobin vegeta
	einstalldocs
}
